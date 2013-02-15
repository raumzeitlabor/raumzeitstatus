# vim:ts=4:sw=4:expandtab
package RaumZeitLabor::Status::Handler::Stream::Full;

use strict;
use parent qw(Tatsumaki::Handler);
use RaumZeitLabor::Status::Status;
use Tatsumaki::MessageQueue;
use JSON::XS;
use v5.10;
our $VERSION = '0.01';
__PACKAGE__->asynchronous(1);

$Tatsumaki::MessageQueue::BacklogLength = 1;

my $status = RaumZeitLabor::Status::Status->new;
my $mq = Tatsumaki::MessageQueue->instance('status');

sub get {
    my ($self) = @_;

    my $client_id = rand(1);
    $self->response->content_type('application/json');
    $mq->poll($client_id, sub {
        my @events = @_;
        for my $event (@events) {
            $self->stream_write($event . "\r\n");
        }
    });

    # keepalive timer
    my $t;
    $t = AE::timer 60, 60, sub {
        scalar $t;
        $self->stream_write("\r\n");
    };
}

1
