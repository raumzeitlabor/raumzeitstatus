#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab
# Script, welches vom Hausbus den Türstatus liest und im JSON/rrd/MySQL ablegt

use strict;
use warnings;

use JSON::XS;
use RRDTool::OO;
use Data::Dumper;
use Net::INET6Glue::INET_is_INET6;
use lib qw(.);
use lib qw(ae-http-stream-lib);
use AnyEvent;
use AnyEvent::HTTP;
use MIME::Base64;
use POSIX qw(strftime);

use v5.10;

use AnyEvent::HTTP::Stream;

sub prefix {
    strftime("%x %X - ", gmtime())
}

$| = 1;

open(my $vf_log, '>>', '/tmp/vflog.log');
$vf_log->autoflush(1);
say $vf_log prefix() . "tuerstatusd.pl starting";

# if status is b0rk, figure it out based on last action
my $b0rk = 0;

my $cv = AE::cv;
my $stream = AnyEvent::HTTP::Stream->new(
    url => 'http://localhost:8888/group/pinpad',
    on_data => sub {
        my ($data) = @_;
        my $pkt = decode_json($data);
        say prefix() . "got data";
        return unless exists $pkt->{payload};
        print prefix() . "payload = " . Dumper($pkt->{payload});

        # display raw values for calibration
        if ($pkt->{payload} =~ /^SRAW /) {
            my $status = $pkt->{payload};
            $status =~ s/^SRAW //g;
            my ($b1, $b2, $b3, $b4) = unpack("CCCC", $status);
            say prefix() . "raw status bytes = $b1, $b2, $b3, $b4";
            return;
        }

        if ($pkt->{payload} =~/^STAT (.+)/) {
            say prefix() . "received status: $1";
            if ($1 eq 'open') {
                new_status('1');
                $b0rk = 0;
                return;
            } elsif ($1 eq 'lock') {
                new_status('0');
                $b0rk = 0;
                return;
            } else {
                # publish b0rk state only once as to not overwrite
                # last action status
                unless ($b0rk) {
                    new_status('?');
                    say prefix() . "switching to fallback mode";
                    $b0rk = 1;
                } else {
                    say prefix() . "remaining in fallback mode";
                }
                return;
            }
        }

        # fallback mode
        if ($pkt->{payload} =~ /^VF \d+ OK/) {
            say $vf_log prefix() . "door was unlocked";
            new_status('1') if ($b0rk);
        } elsif ($pkt->{payload} =~ /^LOCK/) {
            say $vf_log prefix() . "door was locked";
            new_status('0') if ($b0rk);
        }
    },
    on_error => sub {
        my ($fatal, $message) = @_;
        warn "Error fatal=$fatal, message=$message";
        $cv->send;
    });


my $w = AnyEvent->timer(after => 1, interval => 60, cb => sub {
    my $post;
    $post = http_post 'http://localhost:8888/send/pinpad',
        '{"payload":"status"}', sub {
            say prefix() . "requested status";
            undef $post;
        };
});

sub new_status {
    my ($output) = @_;

    say prefix() . "new status: $output";
    say prefix() . "pushing to jail";

    my $username = "foo";
    my $password = "bar";
    my $auth = "Basic " . MIME::Base64::encode("$username:$password", '');
    http_post 'http://status.raumzeitlabor.de/api/update',
        encode_json({ status => $output }),
        headers => {
            Authorization => $auth,
        },
        sub {
            my ($data, $headers) = @_;
            print prefix() . "reply from server: " . Dumper($data);
        };

    my $rrd = RRDTool::OO->new(file => "/tmp/rrd/status-tuer.rrd");
    if ($output eq '1' or $output eq '0') {
        say prefix() . "updating in rrd";
        $rrd->update(values => { 'tuer' => $output } );
    }
}

$cv->recv
