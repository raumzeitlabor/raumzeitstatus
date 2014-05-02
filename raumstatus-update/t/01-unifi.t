#!perl -T
use 5.014;
use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::MockObject;

use AnyEvent::HTTPD;
use JSON::XS;

use Coro;

BEGIN {
    use_ok( 'raumstatusd::Unifi' ) || print "Bail out!\n";
}

diag('Testing raumstatusd::Unifi');

my $httpd = AnyEvent::HTTPD->new(port => undef);
my $port = $httpd->port;

my $expected = { mac => '00:11:22:33:44:55:66', ip => '172.22.37.23', };
my $station_json = {
    data => [
        $expected,
        { mac => '00:11:22:33:44:55:00', ip => '172.22.36.1', },
    ]
};


$httpd->reg_cb(
    '/login' => sub {
        my (undef, $req) = @_;
        $req->respond(
            [ 302, 'ok', { Location => '/manage/s/default' } ]
        );
    },
    '/api/stat/sta' => sub {
        my (undef, $req) = @_;
        $req->respond([
            200, 'ok',
            { 'Content-Type' => 'application/json;charset=ISO-8859-1' },
            encode_json($station_json),
        ]);
    },
);


my $config = { uri => "http://localhost:$port", user => '', pass => '' };

my $unifi = raumstatusd::Unifi->new(config => $config);
# XXX
$unifi->login;

is_deeply($unifi->list_stations, $station_json->{data}, 'list_stations');
is_deeply($unifi->list_dynamic_macs, [ $expected->{mac} ], 'list_dynamic_macs');

my $channel = Coro::Channel->new(1);
$raumzeitstatusd::Instance =
    Test::MockObject->new->set_always('main_queue', $channel);

$unifi->interval(0.01);
$unifi->run;

isa_ok($channel->get, 'raumstatusd::Unifi::Event', 'queue->get 1');
my $e = $channel->get;
isa_ok($e, 'raumstatusd::Unifi::Event', 'queue->get 2');

is_deeply($e->macs, [ $expected->{mac} ], 'event->macs');




done_testing;
