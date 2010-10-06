#!/usr/bin/env perl

use strict;
use warnings;
use HTTP::DAV;
use JSON::XS;
use IO::All;
use lib qw(.);
use davconfig;
use v5.10;


my $dav = HTTP::DAV->new();
$dav->credentials(
	-user => $davconfig::user,
	-pass => $davconfig::pass,
	-url => $davconfig::url,
	-realm => $davconfig::realm
);
$dav->open(-url => $davconfig::url);
if (!$dav->put(-local => 'full.json', -url => "$davconfig::url/full.json")) {
	print "fail: " . $dav->message . "\n";
}

if (!$dav->put(-local => '/var/www/status-1week.png', -url => "$davconfig::url/status-1week.png")) {
	print "fail: " . $dav->message . "\n";
}

# TODO: stattdessen den aggregierten status nutzen, sobald das läuft
my $json = decode_json(io('full.json')->slurp);
my $tuerstatus = $json->{details}->{tuer};
if (!$dav->put(-local => \$tuerstatus, -url => "$davconfig::url/simple.txt")) {
	print "fail: " . $dav->message . "\n";
}
