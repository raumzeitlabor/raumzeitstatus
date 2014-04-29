package RaumZeitLabor::Status::Update;

use 5.014;
use strict;
use warnings FATAL => 'all';

use Carp;
use Time::Piece;

use Log::Log4perl qw/:easy/;
use JSON::XS;
use AnyEvent::HTTP;
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

my $db = DBIx::Simple->connect(
    $CONFIG->{db}{uri}, $CONFIG->{db}{user}, $CONFIG->{db}{pass}
);

my $UNIFI_CTRL = $CONFIG->{unifi}{uri};

sub unifi_login {
    my $cv = AE::cv;
    unifi_request(
        POST => 'login',
        recurse => 0,
        body_form_urlencoded(
            login => 'Login',
            username => $CONFIG->{unifi}{user},
            password => $CONFIG->{unifi}{pass}
        ),
        sub {
            my (undef, $hdr) = @_;
            $cv->send($hdr->{Status} == 302);
        }
    );

    croak('wrong credentials') unless $cv->recv;

    INFO('logged in');
}

sub unifi_stations {
    $cv = AE::cv;
    unifi_request(
        GET => 'api/stat/sta',
        sub {
            my ($body, $hdr) = @_;
            $cv->send(decode_json($body));
        }
    );

    my $stations = $cv->recv;

    INFO(scalar @{ $stations->{data} } . ' stations connected to AP');

    return $stations->{data};
}

sub update_leases {
    my ($stations) = @_;
    $db->begin_work;
    $db->query('DELETE FROM leases');

    for my $station (@$stations) {
        # first_seen, last_seen, uptime, oui, assoc_time
        my $state = ($station->{powersave_enabled} ? 'SLEEPING' : '  ACTIVE');
        INFO(sprintf '%10s | %8s | %25s | %12s | %8s',
                $station->{mac}, $state, $station->{hostname},
                $station->{ip}, $station->{oui}
        );

        update_benutzerdb_lease($db, $station);
    }

    $db->commit;
}

sub unifi_logout {
    $cv = AE::cv;
    unifi_request(GET => 'logout', $cv);
    $cv->recv;

    INFO('logged out');
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
    my ($status) = @_;
    my $username = $CONFIG->{status}{user};
    my $password = $CONFIG->{status}{pass};
    my $url = $CONFIG->{status}{uri};

    my $auth = 'Basic ' . MIME::Base64::encode("$username:$password", '');

    my $status_json = encode_json($status);

    INFO('posting update');

    my $done = AnyEvent->condvar;

    http_post(
        $url,
        $status_json,
        headers => { Authorization => $auth },
        sub {
            my ($data, $headers) = @_;
            $done->send($headers->{Status});
        }
    );

    INFO('DONE (' . $done->recv . ')');
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

    http_request(
        $verb => "$UNIFI_CTRL/$path",
        timeout    => 3,
        persistent => 1,
        session    => $session,
        cookie_jar => $cookies,
        # unifis' SSL implementation is broken, what we might want to do
        # instead is: probe if they have implemented TLS in the mean
        # time and fall back to sslv3 only after failing.
        tls_ctx    => { sslv2 => 0, sslv3 => 1, tlsv1 => 0 },
        @request_args,
    );
}

sub load_config {
    my ($file) = @_;

    open my $fh, '<', $file
        or die "Could not open config file: $file\n";

    my $config = decode_json(do { local $/; <$fh> });

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
