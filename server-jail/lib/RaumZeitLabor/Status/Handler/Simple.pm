# vim:ts=4:sw=4:expandtab
package RaumZeitLabor::Status::Handler::Simple;

use strict;
use parent qw(Tatsumaki::Handler);
use v5.10;
use RaumZeitLabor::Status::Status;
our $VERSION = '0.01';
__PACKAGE__->asynchronous(1);

my $status = RaumZeitLabor::Status::Status->new;

sub get {
    my ($self) = @_;

    $self->response->content_type('text/plain');
    $self->response->headers([ 'Access-Control-Allow-Origin' => '*' ]);
    $self->write($status->total_status);
    $self->finish;
}

1
