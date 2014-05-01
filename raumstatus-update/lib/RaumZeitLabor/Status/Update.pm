package RaumZeitLabor::Status::Update;

use 5.014;
use strict;
use warnings FATAL => 'all';

use Carp;

use AnyEvent::HTTP;

use Log::Log4perl qw/:easy/;
use JSON::XS;
use HTTP::Request::Common ();
use MIME::Base64;

Log::Log4perl->easy_init($DEBUG);

my $UNIFI_CTRL = $CONFIG->{unifi}{uri};

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

1; # End of RaumZeitLabor::Status::Update
