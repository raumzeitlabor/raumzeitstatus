package RaumZeitLabor::Status::Unifi;

use 5.014;
use strict;
use warnings FATAL => 'all';

use Carp;

use Coro;
use AnyEvent::HTTP;

use Log::Log4perl qw/:easy/;
use JSON::XS;
use HTTP::Request::Common ();

Log::Log4perl->easy_init($DEBUG);

use Moo;

has 'config' => (
    is => 'ro',
);

sub station_debuginfo {
    my ($self, $station) = @_;
    # first_seen, last_seen, uptime, oui, assoc_time
    my $state = ($station->{powersave_enabled} ? 'SLEEPING' : 'ACTIVE');
    INFO(sprintf '%10s | %8s | %25s | %13s | %8s',
            $station->{mac}, $state, $station->{hostname},
            $station->{ip}, $station->{oui}
    );
}

sub login {
    my ($self) = @_;

    my (undef, $hdr) = $self->request(
        POST => 'login',
        recurse => 0,
        body_form_urlencoded(
            login => 'Login',
            username => $self->config->{user},
            password => $self->config->{pass},
        )
    );

    if ($hdr->{Status} == 302 and
        $hdr->{location} =~ m{/manage/s/default$}g)
    {
        INFO('logged in');
    }
    # unifi returns status code 200 if our credentials are incorrect
    else {
        croak('wrong credentials');
    }
}

sub list_stations {
    my ($self) = @_;
    state $json = JSON::XS->new->ascii;

    my ($body, $hdr) = $self->request(POST => 'api/stat/sta');

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

sub request {
    my $self = shift @_;

    my $wait = Coro::rouse_cb;

    $self->_unifi_request(@_, $wait);

    return Coro::rouse_wait($wait);
}

sub _unifi_request {
    my ($self, $verb, $path, @request_args) = @_;

    my $unifi_uri = $self->config->{uri};

    state %cookie_jar;
    my $session = "unifi_session_$unifi_uri";
    my $cookies = $cookie_jar{$session} ||= { };

    return http_request(
        $verb => "$unifi_uri/$path",
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
    );

}

1; # End of RaumZeitLabor::Status::Unifi
