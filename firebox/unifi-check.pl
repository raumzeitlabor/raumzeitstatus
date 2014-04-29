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
use sqlconfig;
use DBIx::Simple;
use SQL::Abstract;

$|++;
Log::Log4perl->easy_init($DEBUG);

my $db = DBIx::Simple->connect(
    $sqlconfig::db,
    $sqlconfig::user,
    $sqlconfig::pass
);

my $UNIFI_CTRL = 'https://unifi.vm:8443';
my $UNIFI_user = '';
my $UNIFI_password = '';

# login
my $cv = AE::cv;

unifi_request(
    POST => 'login',
    recurse => 0,
    body_form_urlencoded(
        login => 'Login',
        username => $UNIFI_user,
        password => $UNIFI_password,
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

my @macs = ();
for my $station (@{ $stations->{data} }) {
    # first_seen, last_seen, uptime, oui, assoc_time
    my $state = ($station->{powersave_enabled} ? 'SLEEPING' : '  ACTIVE');
    INFO(sprintf '%10s | %8s | %25s | %12s | %8s',
            $station->{mac}, $state, $station->{hostname},
            $station->{ip}, $station->{oui}
    );

    push @macs, $station->{mac};

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

$db->commit;

my @tmp = $db->select('devices', 'handle', {
    mac => { -in => \@macs }
})->flat;

my @laboranten = keys %{ { map { $_ => 1 } @tmp } };
INFO('laboranten: ' . join ', ', @laboranten);

$cv = AE::cv;
unifi_request(GET => 'logout', $cv);
$cv->recv;

INFO('logged out');

INFO('posting update');

my $username = 'bar';
my $password = 'foo';
my $auth = 'Basic ' . MIME::Base64::encode("$username:$password", '');

my $done = AnyEvent->condvar;
http_post(
    'https://status.raumzeitlabor.de/api/update',
    encode_json(
        {
            details => {
                geraete    => scalar @{ $stations->{data} },
                laboranten => \@laboranten,
            }
        }
    ),
    headers => { Authorization => $auth },
    sub {
        my ($data, $headers) = @_;
        $done->send($headers->{Status});
    }
);

INFO('DONE (' . $done->recv . ')');

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

    state $cookies = { };

    http_request(
        $verb => "$UNIFI_CTRL/$path",
        timeout    => 3,
        persistent => 1,
        session    => 'unifi_session',
        cookie_jar => $cookies,
        tls_ctx    => { sslv2 => 0, sslv3 => 1, tlsv1 => 0 },
        @request_args,
    );
}

