#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab
# Script, welches vom Hausbus den Türstatus liest und im JSON/rrd/MySQL ablegt

use JSON::XS;
use RRDTool::OO;
use DBIx::Simple;
use Data::Dumper;
use Net::INET6Glue::INET_is_INET6;
use IO::All;
use Fcntl qw (:flock);
use lib qw(.);
use lib qw(ae-http-stream-lib);
use Hausbus;
use AnyEvent;
use AnyEvent::HTTP;
use sqlconfig;
use JSON::XS;
use MIME::Base64;

use v5.10;

use AnyEvent::HTTP::Stream;

my $stream = AnyEvent::HTTP::Stream->new(
	url => 'http://localhost:8888/group/pinpad',
	on_data => sub {
		my ($data) = @_;
		my $pkt = decode_json($data);
		return unless exists $pkt->{payload};
		return unless $pkt->{payload} =~ /^STAT /;
		my ($status) = ($pkt->{payload} =~ /^STAT (.+)/);
		say "new status $status";
		my $statuscode;
		if ($status eq 'open') {
			$statuscode = '1';
		} elsif ($status eq 'lock') {
			$statuscode = '0';
		} else {
			$statuscode = '?';
		}
		say "translates to code $statuscode";
		new_status($statuscode);
	});


my $w = AnyEvent->timer(after => 1, interval => 60, cb => sub {
	'{"payload":"status"}' > io('http://localhost:8888/send/pinpad');
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


	my $rrd = RRDTool::OO->new(file => "status-tuer.rrd");
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

AE::cv->recv
