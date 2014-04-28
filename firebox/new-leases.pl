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
use MIME::Base64;
use AnyEvent;
use AnyEvent::HTTP;
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
my $pinger = AnyEvent::FastPing->new();
$pinger->add_range(v172.22.36.1, v172.22.36.255, 1/100);
$pinger->interval(1/1000);
$pinger->max_rtt(0.1);


$pinger->on_recv(sub {
		for (@{ $_[0] }) {
			         printf "%s %g\n", (AnyEvent::Socket::format_address $_->[0]), $_->[1];
				       }
				       return;

    my ($replies) = @_;
    my @replies = map { inet_ntoa($_->[0]) } @{$replies};

    say "replies = " . Dumper(\@replies);

    # Get the user object and set ipv4_reachable(1)
    for my $ip (@replies) {
        for $k (keys %users) {
            my @ips = $users{$k}->ips;
            next unless $ip ~~ @ips;
            $users{$k}->ipv4_reachable(1);
        }
    }
});

my $t;
$t = AnyEvent->timer(
	after => 5,
	cb => sub {
		$done->broadcast;
		undef $t;
	});
$pinger->on_idle(sub {
	});
$pinger->start;

$done->wait;

my @reachable = grep { $users{$_}->ipv4_reachable == 1 } keys %users;

my $rrd = RRDTool::OO->new(file => "status-geraete.rrd");
my $r = @reachable;
$rrd->update(values => { 'geraete' => $r  } );

my $username = "foo";
my $password = "bar";
my $auth = "Basic " . MIME::Base64::encode("$username:$password", '');
$done = AnyEvent->condvar;
http_post 'http://status.raumzeitlabor.de/api/update',
	  encode_json({ details => { geraete => $r }}),
	  headers => {
		  Authorization => $auth,
	  },
	  sub {
		my ($data, $headers) = @_;
		say "reply from server: " . Dumper($data);
		$done->broadcast;
	  };
$done->wait;


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
