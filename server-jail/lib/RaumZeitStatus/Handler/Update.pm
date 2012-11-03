# vim:ts=4:sw=4:expandtab
package RaumZeitStatus::Handler::Update;

use strict;
use parent qw(Tatsumaki::Handler);
use RaumZeitStatus::Status;
use Tatsumaki::MessageQueue;
use JSON::XS;
use v5.10;
our $VERSION = '0.01';
__PACKAGE__->asynchronous(1);

my $status = RaumZeitStatus::Status->new;
my $mq = Tatsumaki::MessageQueue->instance('status');

sub post {
    my ($self) = @_;

    my $old_status = $status->full_status;

    my $update = decode_json($self->request->content);
    if (exists $update->{status}) {
        $status->door_unlocked($update->{status});
    }
    if (exists $update->{details}->{geraete}) {
        $status->device_count($update->{details}->{geraete});
    }
    if (exists $update->{details}->{laboranten}) {
        $status->user($update->{details}->{laboranten});
    }

    # publish the new status to the messagequeue if changed
    my $new_status = $status->full_status;
    if ($new_status ne $old_status) {
        $mq->publish($new_status);
    }

    $self->write(q|{"update":"ok"}|);
    $self->finish;
}

1
