#!/usr/bin/perl

use strict;
use warnings;

use Carp;
use Log::Log4perl qw/:easy/;
use JSON::XS;
use Time::Piece;
use URL::Encode qw/url_encode_utf8/;
use Data::Dumper;
use AnyEvent::HTTP;
use MIME::Base64;

use lib qw(.);
use user;
use sqlconfig;
use DBIx::Simple;

$|++;
Log::Log4perl->easy_init($DEBUG);

my $db = DBIx::Simple->connect(
    $sqlconfig::db,
    $sqlconfig::user,
    $sqlconfig::pass
);

my $UNIFI_CTRL = "https://unifi.vm:8443";

# login
my $cv = AE::cv;
my $cookiejar = {};

my $login_request = http_request POST => $UNIFI_CTRL."/login",
    timeout => 3,
    recurse => 0,
    persistent => 1,
    cookie_jar => $cookiejar,
    tls_ctx => { sslv2 => 0, sslv3 => 1, tlsv1 => 0, },
    body => 
        "login=Login&".
        "username=".url_encode_utf8("foo").
        "&password=".url_encode_utf8("bar"),
    headers => {
        "Content-Type" => "application/x-www-form-urlencoded",
    },
    sub {
        my ($partial_body, $hdr) = @_;
        $cv->send($hdr->{Status} eq "302");
    };

croak "wrong credentials " if (!$cv->recv);
undef $login_request;

INFO "logged in";

# fetch stations
$cv = AE::cv;
my $station_request = http_request GET => $UNIFI_CTRL."/api/stat/sta",
    timeout => 3,
    persistent => 1,
    cookie_jar => $cookiejar,
    tls_ctx => { sslv2 => 0, sslv3 => 1, tlsv1 => 0, },
, sub {
    my ($body, $hdr) = @_;
    $cv->send(decode_json($body));
};

my $stations = $cv->recv;
undef $station_request;
INFO "".@{$stations->{data}} ." stations connected to AP";

$db->begin_work;
$db->query('DELETE FROM leases');

my @macs = ();
for my $station (@{$stations->{data}}) {
    # first_seen, last_seen, uptime, oui, assoc_time
    my $state = ($station->{powersave_enabled} ? "SLEEPING" : "  ACTIVE");
    INFO sprintf("%10s | %8s | %25s | %12s | %8s", $station->{mac}, $state, $station->{hostname}, $station->{ip}, $station->{oui});

    push @macs, $station->{mac} if (time - $station->{last_seen} < 60); # XXX

    # TODO: handle multiple IPs
    $db->insert('leases', {
        ip => $station->{ip},
        mac => $station->{mac},
        ipv4_reachable => (time - $station->{last_seen} < 60), # XXX
        ipv6_reachable => 0,
        hostname => $station->{hostname}
    });

    # update last seen (TODO: ipv6)
    $db->update('devices', {
        lastseen => $station->{last_seen},
    }, {
        mac => $station->{mac},
        updatelastseen => 1
    });
}

$db->commit;

my @tmp = $db->select('devices', 'handle', {
    mac => { -in => \@macs },
})->flat;

my @laboranten = keys %{{ map { $_ => 1 } @tmp }};
INFO "laboranten: " . join ", ", @laboranten;

$cv = AE::cv;
my $logout_request = http_request GET => $UNIFI_CTRL."/logout",
    cookie_jar => $cookiejar,
    sub { $cv->send; };

$cv->recv;
INFO "logged out";

INFO "posting update";

my $username = "bar";
my $password = "foo";
my $auth = "Basic " . MIME::Base64::encode("$username:$password", '');

my $done = AnyEvent->condvar;
http_post 'https://status.raumzeitlabor.de/api/update',
	  encode_json({
          details => {
              geraete => "".@{$stations->{data}},
              laboranten => \@laboranten,
          }
      }),
	  headers => {
		  Authorization => $auth,
	  },
	  sub {
		my ($data, $headers) = @_;
		$done->send($headers->{Status});
	  };

INFO "DONE (" . $done->recv . ")";
