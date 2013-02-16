#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab

package RaumZeitLabor::Status::IRCBot;

use strict;
use warnings;

use AnyEvent;
use AnyEvent::HTTP::Stream;
use AnyEvent::IRC::Client;
use IO::All;
use JSON::XS;
use Data::Dumper;

=head1 NAME

RaumZeitLabor::Status::IRCBot - Der RaumZeitLabor Statusbot fürs IRC.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Postet Updates des RaumZeitStatus in unseren IRC Channel.

=cut

my $server = "irc.hackint.net";
my $port = 6667;
my $nick = "RaumZeitStatus";
my @channels = ("#raumzeitlabor");
my $current_status = '';
my $conn = undef;
my $pkt = undef;
my $laboranten;
my $geraete;

my $stream = AnyEvent::HTTP::Stream->new(
    url => 'http://127.0.0.1:5000/api/stream/full.json',
    on_data => sub {
        my ($data) = @_;
        $pkt = decode_json($data);
        if (defined $pkt && defined $pkt->{details} && defined $pkt->{details}->{laboranten}
            && scalar @{$pkt->{details}->{laboranten}} == 0) {
            $laboranten = ["keiner"];
        } else {
            $laboranten = $pkt->{details}->{laboranten};
            map { $_ =~ s/^(.)/$1/ } @{$laboranten};
        }
        $geraete = $pkt->{details}->{geraete};

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

sub run {
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

                if ($text =~ /^!!status\b/ or
                    $text =~ /^!status\b/) {
                    $conn->send_chan($channel, 'PRIVMSG', ($channel, "Raumstatus: $current_status"));
                } elsif ($text =~ /^!!?weristda\b/) {
                    $conn->send_chan($channel, 'PRIVMSG', ($channel, "Anwesende Laboranten: ".join(", ", @{$laboranten})));
                } elsif ($text =~ /^!!?geräte\b/ or
                         $text =~ /^!!?xn--gerte-ira\b/) {
                    $conn->send_chan($channel, 'PRIVMSG', ($channel, "Aktive Geräte: $geraete"));
                } elsif ($text =~ /^!!?raum\b/ or
                         $text =~ /^!?raum\b/) {
                    $conn->send_chan($channel, 'PRIVMSG', ($channel, "Raumstatus: $current_status. Aktive Geräte: $geraete. Anwesende Laboranten: ".join(", ", @{$laboranten})));
                }

            });

        $conn->connect($server, $port, { nick => $nick, user => 'status' });
        $c->wait;

        # Wait 5 seconds before reconnecting, else we might get banned
        sleep 5;
    }
}


=head1 AUTHOR

Michael Stapelberg C<< <michael@stapelberg.de> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-raumzeitlabor-status-ircbot at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=RaumZeitLabor-Status-IRCBot>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RaumZeitLabor::Status::IRCBot


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=RaumZeitLabor-Status-IRCBot>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/RaumZeitLabor-Status-IRCBot>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/RaumZeitLabor-Status-IRCBot>

=item * Search CPAN

L<http://search.cpan.org/dist/RaumZeitLabor-Status-IRCBot/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Simon Elsbrock.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2 dated June, 1991 or at your option
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

A copy of the GNU General Public License is available in the source tree;
if not, write to the Free Software Foundation, Inc.,
59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.


=cut

1; # End of RaumZeitLabor::Status::IRCBot
