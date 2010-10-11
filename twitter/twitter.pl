#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab

use strict;
use warnings;
use Data::Dumper;
use IO::All;
use File::stat;
use DateTime;
use Net::Twitter;
use AnyEvent;

sub get_status {
    my $file = '/data/www/status.raumzeitlabor.de/htdocs/update/simple.txt';
    my $st = stat($file) or die "No $file: $!";
    my $dt = DateTime->from_epoch(epoch => $st->mtime);
    $dt->set_time_zone('Europe/Berlin');
    my $status = io($file)->slurp;
    my $res;

    chomp($status);
    if ($status eq '?') {
        $res = 'Kann nicht ermittelt werden';
    } elsif ($status eq '1') {
        $res = 'Offen';
    } elsif ($status eq '0') {
        $res = 'Geschlossen';
    } else {
        $res = "Interner Fehler ($status)";
    }

    return "$res (Stand: " . $dt->strftime("%Y-%m-%d %H:%M:%S %z") . ")";
}

my $nt = Net::Twitter->new(
    traits   => [qw/OAuth API::REST/],
    consumer_key    => 'REGISTER-APP-AND-FILL-IN',
    consumer_secret => 'REGISTER-APP-AND-FILL-IN',

    access_token => 'AUTHORIZE-AND-FILL-IN',
    access_token_secret => 'AUTHORIZE-AND-FILL-IN',
);

my $cv = AnyEvent->condvar;
my $old_status = "";

my $w = AnyEvent->timer(
    after => 30.0,
    interval => 30.0,
    cb => sub {
        my $new_status = get_status();
        my ($new_start) = ($new_status =~ /([^\(]+)/);
        my ($old_start) = ($old_status =~ /([^\(]+)/);
        return if defined($new_start) and
                  defined($old_start) and
                  ($new_start eq $old_start);

        # Skip the first update
        if ($old_status eq "") {
            $old_status = $new_status;
            return;
        }

        # Announce new status
        $old_status = $new_status;
 
        $nt->update({
            status => 'Status: ' . get_status(),
            lat => '49.507242',
            long => '8.499177',
            place_id => '8c2c7f5b87502184',
            display_coordinates => 1
        });
    });

$cv->recv
