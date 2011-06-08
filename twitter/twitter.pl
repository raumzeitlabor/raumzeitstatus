#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab

use strict;
use warnings;
use Data::Dumper;
use DateTime;
use Net::Twitter;
use AnyEvent;
use lib qw(/home/rzl/ae-http-stream/);
use AnyEvent::HTTP::Stream;
use JSON::XS;

my $current_status = undef;

my $twitter = Net::Twitter->new(
    traits   => [qw/OAuth API::REST/],
    consumer_key    => 'REGISTER-APP-AND-FILL-IN',
    consumer_secret => 'REGISTER-APP-AND-FILL-IN',
    access_token => 'AUTHORIZE-AND-FILL-IN',
    access_token_secret => 'AUTHORIZE-AND-FILL-IN',
);

my $stream = AnyEvent::HTTP::Stream->new(
    url => 'http://status.raumzeitlabor.de:5000/api/stream/full.json',
    on_data => sub {
        my ($data) = @_;

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

        return if $old_status eq $current_status;
        print "Posting new status $current_status to twitter...\n";
        my $dt = DateTime->now;
        $dt->set_time_zone('Europe/Berlin');
        my $time = $dt->strftime("%Y-%m-%d %H:%M:%S %z");
        $twitter->update({
            status => "Status: $current_status (Stand: $time)",
            lat => '49.507242',
            long => '8.499177',
            place_id => '8c2c7f5b87502184',
            display_coordinates => 1
        });
    },
);

AE::cv->recv
