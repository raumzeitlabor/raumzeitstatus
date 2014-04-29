#!/usr/bin/perl

use strict;
use warnings;
use v5.14;

use Carp;
use Log::Log4perl qw/:easy/;
use JSON::XS;
use Time::Piece;
use Data::Dumper;
use AnyEvent::HTTP;
use HTTP::Request::Common ();
use MIME::Base64;

use lib qw(.);
use DBIx::Simple;
use SQL::Abstract;

$|++;
Log::Log4perl->easy_init($DEBUG);

my $CONFIG = load_config("$ENV{HOME}/raumstatus_config.json");

my $db = DBIx::Simple->connect(
    $CONFIG->{db}{uri}, $CONFIG->{db}{user}, $CONFIG->{db}{pass}
);

my $UNIFI_CTRL = $CONFIG->{unifi}{uri};

# login
my $cv = AE::cv;
unifi_request(
    POST => 'login',
    recurse => 0,
    body_form_urlencoded(
        login => 'Login',
        username => $CONFIG->{unifi}{user},
        password => $CONFIG->{unifi}{pass}
    ),
    sub {
        my (undef, $hdr) = @_;
        $cv->send($hdr->{Status} == 302);
    }
);

croak('wrong credentials') unless $cv->recv;

INFO('logged in');

# fetch stations
$cv = AE::cv;
unifi_request(
    GET => 'api/stat/sta',
    sub {
        my ($body, $hdr) = @_;
        $cv->send(decode_json($body));
    }
);

my $stations = $cv->recv;

INFO(scalar @{ $stations->{data} } . ' stations connected to AP');

$db->begin_work;
$db->query('DELETE FROM leases');

for my $station (@{ $stations->{data} }) {
    # first_seen, last_seen, uptime, oui, assoc_time
    my $state = ($station->{powersave_enabled} ? 'SLEEPING' : '  ACTIVE');
    INFO(sprintf '%10s | %8s | %25s | %12s | %8s',
            $station->{mac}, $state, $station->{hostname},
            $station->{ip}, $station->{oui}
    );


    update_benutzerdb_lease($db, $station);
}

$db->commit;

$cv = AE::cv;
unifi_request(GET => 'logout', $cv);
$cv->recv;

INFO('logged out');

my $status = internal_status($db);

INFO('posting update');

my $done = post_status_update($status);

INFO('DONE (' . $done->recv . ')');

sub internal_status {
    my ($db) = @_;
    my @macs = $db->select(
        'leases', 'mac', {
            ipv4_reachable => 1
        },
    )->flat;

    my @members = $db->select(
        'devices', 'DISTINCT handle', {
            mac => { -in => \@macs }
        }
    )->flat;

    INFO('laboranten: ' . join ', ', @members);

    my %status = (
        details => {
            geraete => scalar @macs,
            laboranten => \@members,
        }
    );

    return \%status;
}

sub post_status_update {
    my ($status) = @_;
    my $username = $CONFIG->{status}{user};
    my $password = $CONFIG->{status}{pass};
    my $url = $CONFIG->{status}{uri};

    my $auth = 'Basic ' . MIME::Base64::encode("$username:$password", '');

    my $status_json = encode_json($status);

    my $done = AnyEvent->condvar;
    http_post(
        $url,
        $status_json,
        headers => { Authorization => $auth },
        sub {
            my ($data, $headers) = @_;
            $done->send($headers->{Status});
        }
    );
    return $done;
}

sub update_benutzerdb_lease {
    my ($db, $station) = @_;

    # TODO: handle multiple IPs
    $db->insert(
        'leases', {
            ip             => $station->{ip},
            mac            => $station->{mac},
            ipv4_reachable => 1,
            ipv6_reachable => 0,
            hostname       => $station->{hostname}
        }
    );

    # update last seen (TODO: ipv6)
    $db->update(
        'devices',
        { lastseen => $station->{last_seen} },
        {
            mac => $station->{mac},
            updatelastseen => 1
        }
    );
}

# helper function for AE::HTTP::http_request.
# takes a list of form parameters and returns a list
# of 'body' and 'headers' arguments.
sub body_form_urlencoded {
    my (@form) = @_;

    # the URL doesn't matter, because we only use the ->content
    my $r = HTTP::Request::Common::POST('http://', \@form);

    return (
        body => $r->content,
        headers => { 'Content-Type' => 'application/x-www-form-urlencoded' },
    );
}

sub unifi_request {
    my ($verb, $path, @request_args) = @_;

    state %cookie_jar;
    my $session = "unifi_session_$UNIFI_CTRL";
    my $cookies = $cookie_jar{$session} ||= { };

    http_request(
        $verb => "$UNIFI_CTRL/$path",
        timeout    => 3,
        persistent => 1,
        session    => $session,
        cookie_jar => $cookies,
        # unifis' SSL implementation is broken, what we might want to do
        # instead is: probe if they have implemented TLS in the mean
        # time and fall back to sslv3 only after failing.
        tls_ctx    => { sslv2 => 0, sslv3 => 1, tlsv1 => 0 },
        @request_args,
    );
}

sub load_config {
    my ($file) = @_;

    open my $fh, '<', $file
        or die "Could not open config file: $file\n";

    my $config = decode_json(do { local $/; <$fh> });

    for my $module (qw/unifi status db/) {
        die "config for $module does not exist."
            unless exists $config->{$module};

        die "config for $module is incomplete"
            unless 3 == grep { $config->{$module}{$_} }
                            qw/uri user pass/;
    }

    return $config;
}
