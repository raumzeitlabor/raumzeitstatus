#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab
# TODO: ipv6 reachability
# TODO: türstatus auch ohne die blackbox zum rzl-jail pushen


use lib qw(.);
use user;
use sqlconfig;

use IO::All;
use Fcntl qw (:flock);
use JSON::XS;
use RRDTool::OO;
use AnyEvent;
use AnyEvent::FastPing;
use IO::Socket;

use DBIx::Simple;

use Text::DHCPLeases;
use Data::Dumper;
use v5.10;

my %users;
my $db = DBIx::Simple->connect(
    $sqlconfig::db,
    $sqlconfig::user,
    $sqlconfig::pass
);

my $leases = Text::DHCPLeases->new(file => "/var/lib/dhcp/dhcpd.leases");

foreach my $l ($leases->get_objects) {
    next unless $l->binding_state eq 'active';

    my $mac = $l->mac_address;
    if (!defined($users{$mac})) {
        $users{$mac} = user->new(mac => $mac);
    }
    $users{$mac}->add_ip($l->ip_address);
    if (defined($l->client_hostname)) {
        $users{$mac}->hostname($l->client_hostname);
    }
}

##
# now ping the whole subnet
##

my $done = AnyEvent->condvar;

AnyEvent::FastPing::register_cb sub {
    my ($replies) = @_;
    my @replies = map { inet_ntoa($_->[0]) } @{$replies};

    # Get the user object and set ipv4_reachable(1)
    for my $ip (@replies) {
        for $k (keys %users) {
            my @ips = $users{$k}->ips;
            next unless $ip ~~ @ips;
            $users{$k}->ipv4_reachable(1);
        }
    }
};

AnyEvent::FastPing::icmp_ping
    [ [v172.22.36.1, v172.22.36.255, .01] ],
    .001,
    0x12345678,
    sub {
        $done->broadcast;
    };

$done->wait;

my @reachable = grep { $users{$_}->ipv4_reachable == 1 } keys %users;

my $rrd = RRDTool::OO->new(file => "status-geraete.rrd");
my $r = @reachable;
$rrd->update(values => { 'geraete' => $r  } );

open LOCKFILE, "<full.json" or die "Cannot open full.json";
flock(LOCKFILE, LOCK_EX);
my $file = io('full.json');
my $json = decode_json($file->slurp);
$json->{details}->{geraete} = $r;
encode_json($json) > $file;
close LOCKFILE or die "Cannot close full.json";

exit 1 unless defined($db);
$db->begin_work;
$db->query('DELETE FROM leases');
print "done, inserting:\n";
for my $mac (keys %users) {
    # TODO: handle multiple IPs
    my @ips = $users{$mac}->ips;
    $db->insert('leases', {
        ip => $ips[0],
        mac => $mac,
        ipv4_reachable => $users{$mac}->ipv4_reachable,
        ipv6_reachable => 0,
        hostname => $users{$mac}->hostname
    });
    print "MAC $mac, ";
    print "reachable: " . $users{$mac}->ipv4_reachable . ", ";
    print "host " . $users{$mac}->hostname if (defined($users{$mac}->hostname));
    print " ( " . $ips[0] . ")";
    say '';
}
$db->commit;
