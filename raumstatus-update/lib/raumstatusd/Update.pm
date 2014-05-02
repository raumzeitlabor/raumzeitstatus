package raumstatusd::Update;

use 5.014;
use strict;
use warnings FATAL => 'all';

use Carp;

use Coro;
use AnyEvent::HTTP;

use Log::Log4perl qw/:easy/;
use JSON::XS;
use HTTP::Request::Common ();
use MIME::Base64;

Log::Log4perl->easy_init($DEBUG);

use Moo;

has 'config' => (
    is => 'ro',
);

sub post_status_update {
    my ($self, $status, $done) = @_;
    my $username = $self->config->{user};
    my $password = $self->config->{pass};
    my $url = $self->config->{uri};

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

1; # End of raumstatusd::Update
