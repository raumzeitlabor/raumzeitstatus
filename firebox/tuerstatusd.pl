#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab
# Script, welches vom Hausbus den Türstatus liest und im JSON/rrd/MySQL ablegt

use strict;
use warnings;

use JSON::XS;
use RRDTool::OO;
use DBIx::Simple;
use Data::Dumper;
use Net::INET6Glue::INET_is_INET6;
use lib qw(.);
use lib qw(ae-http-stream-lib);
use AnyEvent;
use AnyEvent::HTTP;
use sqlconfig;
use MIME::Base64;
use POSIX qw(strftime);
use IO::Handle;

use v5.10;

use AnyEvent::HTTP::Stream;

sub prefix {
	strftime("%x %X - ", gmtime())
}

$| = 1;

open(my $vf_log, '>>', '/tmp/vflog.log');
$vf_log->autoflush(1);
say $vf_log prefix() . "tuerstatusd.pl starting";

my $cv = AE::cv;
my $stream = AnyEvent::HTTP::Stream->new(
	url => 'http://localhost:8888/group/pinpad',
	on_data => sub {
		my ($data) = @_;
		my $pkt = decode_json($data);
		say $data;
		return unless exists $pkt->{payload};
		if ($pkt->{payload} =~ /^SRAW /) {
			my $status = $pkt->{payload};
			$status =~ s/^SRAW //g;
			my ($b1, $b2, $b3, $b4) = unpack("CCCC", $status);
			say "raw status bytes = $b1, $b2, $b3, $b4";
			return;
		}
		return if ($pkt->{payload} !~ /^STAT / && $pkt->{payload} !~ /^EE/ && $pkt->{payload} !~ /^X / && $pkt->{payload} !~ /^VF /);
		if ($pkt->{payload} =~ /^VF /) {
			say $vf_log prefix() . "VF: $pkt->{payload}";
		}
		say "payload = " . Dumper($pkt->{payload});
		return unless $pkt->{payload} =~ /^STAT /;
		my ($status) = ($pkt->{payload} =~ /^STAT (.+)/);
		my $statuscode;
		if ($status eq 'open') {
			$statuscode = '1';
		} elsif ($status eq 'lock') {
			$statuscode = '0';
		} else {
			$statuscode = '?';
		}
		say "status $status (code $statuscode)";
		new_status($statuscode);
	},
    on_error => sub {
        my ($fatal, $message) = @_;
        warn "Error fatal=$fatal, message=$message";
        $cv->send;
    });


my $w = AnyEvent->timer(after => 1, interval => 60, cb => sub {
	my $post;
	$post = http_post 'http://localhost:8888/send/pinpad', '{"payload":"status"}', sub { say "posted!"; undef $post; };
});

sub new_status {
	my ($output) = @_;

	say "pushing to jail";

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
			  say "reply from server: " . Dumper($data);
		  };


	my $rrd = RRDTool::OO->new(file => "/tmp/rrd/status-tuer.rrd");
	if ($output eq '1' or $output eq '0') {
		say "updating in rrd";
	$rrd->update(values => { 'tuer' => $output } );
	}

	#my $db = DBIx::Simple->connect(
	#    $sqlconfig::db,
	#    $sqlconfig::user,
	#    $sqlconfig::pass
	#) or die "Cannot connect to database: $!";

	#$db->begin_work;
	#$db->query('DELETE FROM tuerstatus');
	#$db->insert('tuerstatus', { status => $output });
	#$db->commit;
}

$cv->recv
