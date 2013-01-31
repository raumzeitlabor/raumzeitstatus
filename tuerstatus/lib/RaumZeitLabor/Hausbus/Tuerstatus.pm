#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab

package RaumZeitLabor::Hausbus::Tuerstatus;

use strict;
use warnings;

our $VERSION = '1.00';

=head1 NAME

RaumZeitLabor::Hausbus::Tuerstatus - queries the pinpad-controller via
Hausbus and publishes the door state to our homepage.

=head1 VERSION

Version 1.00

=cut

use Sys::Syslog;
use YAML::Syck;
use JSON::XS;
use RRDTool::OO;
use Data::Dumper;
use AnyEvent;
use AnyEvent::HTTP;
use MIME::Base64;
use POSIX qw(strftime);

use v5.10;

use AnyEvent::HTTP::Stream;

$| = 1;

my $cfg;
if (-e 'tuerstatusd.yml') {
    $cfg = LoadFile('tuerstatusd.yml');
} elsif (-e '/etc/tuerstatusd.yml') {
    $cfg = LoadFile('/etc/tuerstatusd.yml');
} else {
    die "Could not load ./tuerstatusd.yml or /etc/tuerstatusd.yml";
}

if (!exists($cfg->{Hausbus}) || !exists($cfg->{RaumZeitStatus})) {
    die "Configuration sections incomplete: need Hausbus and RaumZeitStatus";
}

# if status is b0rk, figure it out based on last action
my $b0rk = 0;
my $fallback_status;

sub new_status {
    my ($output) = @_;

    syslog 'info', "new status: $output";
    syslog 'debug', "pushing to jail";

    my $username = $cfg->{RaumZeitStatus}->{user};
    my $password = $cfg->{RaumZeitStatus}->{pass};
    my $auth = "Basic " . MIME::Base64::encode("$username:$password", '');
    http_post 'http://status.raumzeitlabor.de/api/update',
        encode_json({ status => $output }),
        headers => {
            Authorization => $auth,
        },
        sub {
            my ($data, $headers) = @_;
            syslog 'debug', "reply from server: " . Dumper($data);
        };

    my $rrd = RRDTool::OO->new(file => "/var/cache/rrd/status-tuer.rrd");
    if ($output eq '1' or $output eq '0') {
        syslog 'debug', "updating rrd";
        $rrd->update(values => { 'tuer' => $output } );
    }
}

sub run {
    openlog 'tuerstatusd', 'pid', 'daemon';
    syslog 'info', 'Starting up';

    my $cv = AE::cv;
    my $stream = AnyEvent::HTTP::Stream->new(
        url => 'http://'.$cfg->{Hausbus}->{host}.'/group/pinpad',
        on_data => sub {
            my ($data) = @_;
            my $pkt = decode_json($data);
            syslog 'debug', 'got reply from hausbus';
            return unless exists $pkt->{payload};
            syslog 'debug', "payload = " . Dumper($pkt->{payload});

            # display raw values for calibration
            if ($pkt->{payload} =~ /^SRAW /) {
                my $status = $pkt->{payload};
                $status =~ s/^SRAW //g;
                my ($b1, $b2, $b3, $b4) = unpack("CCCC", $status);
                syslog 'debug', "raw status bytes = $b1, $b2, $b3, $b4";
                return;
            }

            if ($pkt->{payload} =~/^STAT (.+)/) {
                syslog 'debug', "received status: $1";
                if ($1 eq 'open') {
                    new_status('1');
                    $b0rk = 0;
                    return;
                } elsif ($1 eq 'lock') {
                    new_status('0');
                    $b0rk = 0;
                    return;
                } else {
                    # publish b0rk state only once to avoid overwriting fallback status
                    unless ($b0rk) {
                        new_status('?');
                        syslog 'warning', "switching to fallback mode";
                        $b0rk = 1;
                    } else {
                        # update fallback status (otherwise it will timeout)
                        new_status($fallback_status) if defined $fallback_status;
                        syslog 'debug', "remaining in fallback mode";
                    }
                    return;
                }
            }

            # fallback mode
            if ($pkt->{payload} =~ /^VF \d+ OK/ || $pkt->{payload} =~ /^OPEN/) {
                syslog 'info', "door was unlocked";
                $fallback_status = 1;
            } elsif ($pkt->{payload} =~ /^LOCK/) {
                syslog 'info', "door was locked";
                $fallback_status = 0;
            }
        },
        on_error => sub {
            my ($fatal, $message) = @_;
            syslog 'err', "Error fatal=$fatal, message=$message";
            $cv->send;
        });


    # status poller
    my $w = AnyEvent->timer(after => 1, interval => 60, cb => sub {
        my $post;
        $post = http_post 'http://'.$cfg->{Hausbus}->{host}.'/send/pinpad',
            '{"payload":"status"}', sub {
            syslog 'debug', "requested status";
            undef $post;
            };
    });

    syslog 'info', "tuerstatusd initialized...";
    AE::cv->recv
}

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Michael Stapelberg, Simon Elsbrock.

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

42;
