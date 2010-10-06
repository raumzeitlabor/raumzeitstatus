#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab
# Dieses Script polled vom Etherrape den Türstatus

use JSON::XS;
use RRDTool::OO;
use DBIx::Simple;
use Data::Dumper;
use Net::INET6Glue::INET_is_INET6;
use IO::All;
use Fcntl qw (:flock);
use lib qw(.);
use sqlconfig;

use v5.10;

# reconfigure the etherrape
io('http://FOO/ecmd?io+set+ddr+0+ff')->slurp;
io('http://FOO/ecmd?io+set+port+0+ff')->slurp;

my $output = '?';
my $status = io('http://FOO/ecmd?io+get+pin+0')->slurp;
if ($status =~ /port 0: ([0-9a-fx]*)/) {
	my ($hex) = ($status =~ /port 0: ([0-9a-fx]*)/);
    say "status = $status, hex = $hex";
	if ($hex eq '0xff') {
		$output = '1';
    } elsif ($hex eq '0xbf') {
        $output = '0';
    }
}

say "output: $output";
# TODO: push this to the rzl-jail

my $rrd = RRDTool::OO->new(file => "status-tuer.rrd");
if ($output eq '1' or $output eq '0') {
	say "updating in rrd";
$rrd->update(values => { 'tuer' => $output } );
}

open LOCKFILE, "<full.json" or die "Cannot open full.json";
flock(LOCKFILE, LOCK_EX);
my $file = io('full.json');
my $json = decode_json($file->slurp);
$json->{details}->{tuer} = $output;
$json->{status} = $output;
encode_json($json) > $file;
close LOCKFILE or die "Cannot close full.json";



my $db = DBIx::Simple->connect(
    $sqlconfig::db,
    $sqlconfig::user,
    $sqlconfig::pass
) or die "Cannot connect to database: $!";

$db->begin_work;
$db->query('DELETE FROM tuerstatus');
$db->insert('tuerstatus', { status => $output });
$db->commit;
