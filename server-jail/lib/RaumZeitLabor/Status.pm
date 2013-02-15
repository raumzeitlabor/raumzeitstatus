# vim:ts=4:sw=4:expandtab
package RaumZeitLabor::Status;

use strict;
use v5.10;
our $VERSION = '0.01';

use Tatsumaki::Application;
use Tatsumaki::Handler;

# Handlers
use RaumZeitLabor::Status::Handler::Full;
use RaumZeitLabor::Status::Handler::Stream::Full;
use RaumZeitLabor::Status::Handler::Simple;
use RaumZeitLabor::Status::Handler::Update;

sub webapp {
    my $class = shift;

    my $app = Tatsumaki::Application->new([
        '/api/full.json' => 'RaumZeitLabor::Status::Handler::Full',
        '/api/stream/full.json' => 'RaumZeitLabor::Status::Handler::Stream::Full',
        '/api/simple(|.txt)' => 'RaumZeitLabor::Status::Handler::Simple',
        '/api/update' => 'RaumZeitLabor::Status::Handler::Update',
    ]);

    $app->psgi_app;
}

1
