# vim:ts=4:sw=4:expandtab
package RaumZeitStatus::Handler::Full;

use strict;
use parent qw(Tatsumaki::Handler);
use RaumZeitStatus::Status;
use JSON::XS;
use v5.10;
our $VERSION = '0.01';
__PACKAGE__->asynchronous(1);

my $status = RaumZeitStatus::Status->new;

sub get {
    my ($self) = @_;

    $self->response->content_type('application/json');
    $self->write($status->full_status);
    $self->finish;
}

1
