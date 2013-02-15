# vim:ts=4:sw=4:expandtab
package RaumZeitLabor::Status::Handler::Full;

use strict;
use parent qw(Tatsumaki::Handler);
use RaumZeitLabor::Status::Status;
use JSON::XS;
use v5.10;
our $VERSION = '0.01';
__PACKAGE__->asynchronous(1);

my $status = RaumZeitLabor::Status::Status->new;

sub get {
    my ($self) = @_;

    $self->response->content_type('application/json');
    $self->response->headers([ 'Access-Control-Allow-Origin' => '*' ]);
    $self->write($status->full_status);
    $self->finish;
}

1
