# vim:ts=4:sw=4:expandtab
package RaumZeitStatus::Status;

use strict;
use Moose;
use MooseX::Singleton;
use AnyEvent;
use JSON::XS;
use Tatsumaki::MessageQueue;

has 'door_unlocked' => (
    isa => 'Bool',
    traits => ['Bool'],
    is => 'rw',
    predicate => 'lockstate_available',
    clearer => 'clear_lockstate',
    trigger => \&_update_door_unlocked,
);

has 'device_count' => (
    isa => 'Int',
    is => 'rw',
    predicate => 'device_count_available',
    clearer => 'clear_device_count',
);

has 'user' => (
    isa => 'ArrayRef',
    is => 'rw',
    predicate => 'user_available',
    clearer => 'clear_user',
);

has '_timer' => (
    isa => 'Ref',
    is => 'rw',
);

has '_mq' => (
    isa => 'Ref',
    is => 'rw',
    default => sub {
        Tatsumaki::MessageQueue->instance('status')
    },
);

sub _update_door_unlocked {
    my ($self) = @_;

    $self->_timer(AE::timer 300, 0, sub {
        $self->clear_lockstate;
        $self->clear_device_count;
        $self->_mq->publish($self->full_status);
    });
}

#
# returns '?', '0' or '1' as total status
#
sub total_status {
    my ($self) = @_;

    ($self->lockstate_available ? $self->door_unlocked : '?')
}

#
# returns the full status
#
sub full_status {
    my ($self) = @_;

    # TODO: npm-status miteinbauen
    my %reply = (
        status => $self->total_status,
        details => {
            tuer => ($self->lockstate_available ? $self->door_unlocked : '?'),
            geraete => ($self->device_count_available ? $self->device_count : '?'),
            laboranten => ($self->user_available ? $self->user : []),
        }
    );

    return encode_json \%reply;
}

# TODO: npm
#{"status":"1","details":{"tuer":"1","npm":{"port4":"0","port3":"0","port7":"0","port2":"1","port8":"0","port5":"0","port1":"1","port6":"0"},"geraete":8}}#


__PACKAGE__->meta->make_immutable;

1
