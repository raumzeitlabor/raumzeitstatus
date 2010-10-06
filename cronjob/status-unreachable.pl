#!/usr/bin/env perl

use strict;
use warnings;
use File::stat;
use DateTime;
use IO::Handle;
use JSON::XS;
use IO::All;

my $file = '/data/www/status.raumzeitlabor.de/htdocs/update/simple.txt';
my $st = stat($file) or die "No $file: $!";
my $duration = DateTime->now() - DateTime->from_epoch(epoch => $st->mtime);
exit 0 if $duration->delta_minutes <= 5;

open my $fh, '>', $file;
$fh->print('?');

$file = io('full.json');
my $json = decode_json($file->slurp);
$json->{details}->{tuer} = '?';
$json->{status} = '?';
encode_json($json) > $file;

