# vim:ts=4:sw=4:expandtab
package RaumZeitStatus;

use strict;
use v5.10;
our $VERSION = '0.01';

use Tatsumaki::Application;
use Tatsumaki::Handler;

# Handlers
use RaumZeitStatus::Handler::Full;
use RaumZeitStatus::Handler::Stream::Full;
use RaumZeitStatus::Handler::Simple;
use RaumZeitStatus::Handler::Update;

sub webapp {
    my $class = shift;

    my $app = Tatsumaki::Application->new([
        '/api/full.json' => 'RaumZeitStatus::Handler::Full',
        '/api/stream/full.json' => 'RaumZeitStatus::Handler::Stream::Full',
        '/api/simple(|.txt)' => 'RaumZeitStatus::Handler::Simple',
        '/api/update' => 'RaumZeitStatus::Handler::Update',
    ]);

    $app->psgi_app;
}

1
