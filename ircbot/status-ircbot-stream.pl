#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab

use strict;
use warnings;
use lib qw(/home/rzl/ae-http-stream/);
use AnyEvent;
use AnyEvent::HTTP::Stream;
use AnyEvent::IRC::Client;
use IO::All;
use JSON::XS;
use Data::Dumper;

my $server = "irc.hackint.net";
my $port = 6667;
my $nick = "RaumZeitStatus";
my @channels = qw(#raumzeitlabor);
my $current_status = '';
my $conn = undef;

my $stream = AnyEvent::HTTP::Stream->new(
    url => 'http://status.raumzeitlabor.de:5000/api/stream/full.json',
    on_data => sub {
        my ($data) = @_;

        print "data: " . Dumper($data) . "\n";
	my $pkt = decode_json($data);
	my $status = $pkt->{status};
my $old_status = $current_status;
    if ($status eq '?') {
        $current_status = 'Kann nicht ermittelt werden';
    } elsif ($status eq '1') {
        $current_status = 'Offen';
    } elsif ($status eq '0') {
        $current_status = 'Geschlossen';
    } else {
        $current_status = "Interner Fehler ($status)";
    }
if ($old_status ne $current_status) {
	if (defined($conn)) {
            for my $channel (@channels) {
                $conn->send_chan($channel, 'PRIVMSG', ($channel, "Neuer Status: $current_status"));
            }
	}
}
},
);

while (1) {
    print "Connecting...\n";
    my $old_status = "";
    my $c = AnyEvent->condvar;
    $conn = AnyEvent::IRC::Client->new;

    $conn->reg_cb(
        registered => sub {
            print "Connected, joining channels\n";
            $conn->send_srv(JOIN => $_) for @channels;
        });

    $conn->reg_cb(disconnect => sub { $c->broadcast });

    $conn->reg_cb(
        publicmsg => sub {
            my ($conn, $channel, $ircmsg) = @_;
            my $text = $ircmsg->{params}->[1];

            if ($text =~ /^!!raum/ or
                $text =~ /^!!status/ or
                $text =~ /^!raum/ or
                $text =~ /^!status/) {
                $conn->send_chan($channel, 'PRIVMSG', ($channel, "Raumstatus: $current_status"));
            } elsif ($text =~ /^!!?weristda/) {
                $conn->send_chan($channel, 'PRIVMSG', ($channel, "Anwesende Laboranten: ".join(", ", $pkt->{laboranten})));
            }
        });

    $conn->connect($server, $port, { nick => $nick, user => 'status' });
    $c->wait;

    # Wait 5 seconds before reconnecting, else we might get banned
    sleep 5;
}
