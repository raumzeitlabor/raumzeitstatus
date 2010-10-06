#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab

use strict;
use warnings;
use AnyEvent;
use AnyEvent::IRC::Client;
use IO::All;

my $server = "irc.hackint.net";
my $port = 6667;
my $nick = "RaumZeitStatus";
my @channels = qw(#raumzeitlabor);

sub get_status {
    my $status = io('/data/www/status.raumzeitlabor.de/htdocs/update/simple.txt')->slurp;
    chomp($status);
    if ($status eq '?') {
        return 'Kann nicht ermittelt werden';
    } elsif ($status eq '1') {
        return 'Offen';
    } elsif ($status eq '0') {
        return 'Geschlossen';
    } else {
        return "Interner Fehler ($status)";
    }
}

while (1) {
    print "Connecting...\n";
    my $old_status = "";
    my $c = AnyEvent->condvar;
    my $conn = AnyEvent::IRC::Client->new;
    my $w = AnyEvent->timer(
        after => 30.0,
        interval => 30.0,
        cb => sub {
            my $new_status = get_status();
            return if $new_status eq $old_status;

            # Skip the first update
            if ($old_status eq "") {
                $old_status = $new_status;
                return;
            }

            # Announce new status
            $old_status = $new_status;

            for my $channel (@channels) {
                $conn->send_chan($channel, 'PRIVMSG', ($channel, "Neuer Status: $new_status"));
            }

        }
    );

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
                $conn->send_chan($channel, 'PRIVMSG', ($channel, "Raumstatus: " . get_status()));
            }
        });

    $conn->connect($server, $port, { nick => $nick, user => 'status' });
    $c->wait;

    # Wait 5 seconds before reconnecting, else we might get banned
    sleep 5;
}
