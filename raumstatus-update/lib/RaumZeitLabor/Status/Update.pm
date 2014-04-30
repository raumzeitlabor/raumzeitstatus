package RaumZeitLabor::Status::Update;

use 5.014;
use strict;
use warnings FATAL => 'all';

use Carp;
use Time::Piece;

use EV;
use Coro;
use AnyEvent;
# initialize AnyEvent as soon as possible to make
# sure integration of EV/Coro/AnyEvent works as expected.
BEGIN { AnyEvent::detect; }

use AnyEvent::HTTP;

use Log::Log4perl qw/:easy/;
use JSON::XS;
use HTTP::Request::Common ();
use MIME::Base64;

use DBIx::Simple;
use SQL::Abstract;

=head1 NAME

RaumZeitLabor::Status::Update - The great new RaumZeitLabor::Status::Update!

=head1 VERSION

Version 0.0.001

=cut

our $VERSION = '0.000.001';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

=cut

Log::Log4perl->easy_init($DEBUG);

my $CONFIG = load_config("$ENV{HOME}/raumstatus_config.json");

my $UNIFI_CTRL = $CONFIG->{unifi}{uri};

sub connect_db {
    return DBIx::Simple->connect(
        $CONFIG->{db}{uri}, $CONFIG->{db}{user}, $CONFIG->{db}{pass}
    );
}
sub run {
    my $db = connect_db();

    unifi_login();

    my $stations = unifi_stations();

    station_debuginfo($_) for @$stations;
    update_leases($db, $stations);

    my $status = internal_status($db);

    post_status_update($status);
}

sub station_debuginfo {
    my ($station) = @_;
    # first_seen, last_seen, uptime, oui, assoc_time
    my $state = ($station->{powersave_enabled} ? 'SLEEPING' : 'ACTIVE');
    INFO(sprintf '%10s | %8s | %25s | %13s | %8s',
            $station->{mac}, $state, $station->{hostname},
            $station->{ip}, $station->{oui}
    );
}

sub unifi_login {
    my ($cb) = @_;

    my (undef, $hdr) = unifi_request(
        POST => 'login',
        recurse => 0,
        body_form_urlencoded(
            login => 'Login',
            username => $CONFIG->{unifi}{user},
            password => $CONFIG->{unifi}{pass},
        )
    );

    if ($hdr->{Status} == 302 and
        $hdr->{location} eq "$UNIFI_CTRL/manage/s/default")
    {
        INFO('logged in');
    }
    # unifi returns status code 200 if our credentials are incorrect
    else {
        croak('wrong credentials');
    }
}

sub unifi_stations {
    state $json = JSON::XS->new->ascii;

    my ($body, $hdr) = unifi_request(POST => 'api/stat/sta');

    my $stations;
    if ($hdr->{Status} == 200 and
        $hdr->{'content-type'} eq 'application/json;charset=ISO-8859-1')
    {
        $stations = $json->decode($body)->{data};
        INFO(scalar @$stations . ' stations connected to AP');
        return $stations;
    }

    return;
}

sub update_leases {
    my ($db, $stations) = @_;
    $db->begin_work;
    $db->query('DELETE FROM leases');

    for my $station (@$stations) {
        update_benutzerdb_lease($db, $station);
    }

    $db->commit;
}

sub internal_status {
    my ($db) = @_;
    my @macs = $db->select(
        'leases', 'mac', {
            ipv4_reachable => 1
        },
    )->flat;

    my @members = $db->select(
        'devices', 'DISTINCT handle', {
            mac => { -in => \@macs }
        }
    )->flat;

    INFO('laboranten: ' . join ', ', @members);

    my %status = (
        details => {
            geraete => scalar @macs,
            laboranten => \@members,
        }
    );

    return \%status;
}

sub post_status_update {
    my ($status, $done) = @_;
    my $username = $CONFIG->{status}{user};
    my $password = $CONFIG->{status}{pass};
    my $url = $CONFIG->{status}{uri};

    my $auth = 'Basic ' . MIME::Base64::encode("$username:$password", '');

    my $status_json = encode_json($status);

    INFO('posting update');

    my $wait = Coro::rouse_cb;

    http_post(
        $url,
        $status_json,
        headers => { Authorization => $auth },
        $wait
    );

    my ($data, $headers) = Coro::rouse_wait($wait);

    INFO('DONE (' . $headers->{Status} . ')');
}

sub update_benutzerdb_lease {
    my ($db, $station) = @_;

    # TODO: handle multiple IPs
    $db->insert(
        'leases', {
            ip             => $station->{ip},
            mac            => $station->{mac},
            ipv4_reachable => 1,
            ipv6_reachable => 0,
            hostname       => $station->{hostname}
        }
    );

    # update last seen (TODO: ipv6)
    $db->update(
        'devices',
        { lastseen => $station->{last_seen} },
        {
            mac => $station->{mac},
            updatelastseen => 1
        }
    );
}

# helper function for AE::HTTP::http_request.
# takes a list of form parameters and returns a list
# of 'body' and 'headers' arguments.
sub body_form_urlencoded {
    my (@form) = @_;

    # the URL doesn't matter, because we only use the ->content
    my $r = HTTP::Request::Common::POST('http://', \@form);

    return (
        body => $r->content,
        headers => { 'Content-Type' => 'application/x-www-form-urlencoded' },
    );
}

sub unifi_request {
    my ($verb, $path, @request_args) = @_;

    state %cookie_jar;
    my $session = "unifi_session_$UNIFI_CTRL";
    my $cookies = $cookie_jar{$session} ||= { };

    my $wait = Coro::rouse_cb;

    http_request(
        $verb => "$UNIFI_CTRL/$path",
        # never time out this connection,
        # we want to keep reusing it as long as possible
        timeout    => 0,

        persistent => 1,
        session    => $session,
        cookie_jar => $cookies,
        # unifis' SSL implementation is broken, what we might want to do
        # instead is: probe if they have implemented TLS in the mean
        # time and fall back to sslv3 only after failing.
        tls_ctx    => { sslv2 => 0, sslv3 => 1, tlsv1 => 0 },
        @request_args,
        $wait
    );

    return Coro::rouse_wait($wait);
}

sub load_config {
    my ($file) = @_;

    open my $fh, '<', $file
        or die "Could not open config file: $file\n";

    # allow comments and trailing commata in lists
    my $json = JSON::XS->new->relaxed(1);

    my $config = $json->decode(do { local $/; <$fh> });

    for my $module (qw/unifi status db/) {
        die "config for $module does not exist."
            unless exists $config->{$module};

        die "config for $module is incomplete"
            unless 3 == grep { $config->{$module}{$_} }
                            qw/uri user pass/;
    }

    return $config;
}

1; # End of RaumZeitLabor::Status::Update
__END__

=head1 AUTHOR

Maik Fischer, C<< <maikf at qu.cx> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-raumzeitlabor-status-update at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=RaumZeitLabor-Status-Update>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RaumZeitLabor::Status::Update


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=RaumZeitLabor-Status-Update>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/RaumZeitLabor-Status-Update>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/RaumZeitLabor-Status-Update>

=item * Search CPAN

L<http://search.cpan.org/dist/RaumZeitLabor-Status-Update/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Maik Fischer.

This program is distributed under the (Revised) BSD License:
L<http://www.opensource.org/licenses/BSD-3-Clause>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

* Neither the name of Maik Fischer's Organization
nor the names of its contributors may be used to endorse or promote
products derived from this software without specific prior written
permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

# vim: set ts=4 sw=4 sts=4 expandtab:
