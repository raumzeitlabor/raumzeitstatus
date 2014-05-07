package raumstatusd::base;
use strict;
use warnings;
use utf8;
use feature ':5.14';

use Moo ();
use Carp;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

sub import {
    my $class = shift;
    my $caller = caller;

    # export some boilerplate to our caller
    strict->import;
    warnings->import(FATAL => 'all');
    feature->import(':5.14');
    utf8->import;

    # export nonlexical modules.
    # we have to fake caller() for them.
    local $@;
    eval << "EOC";
        package $caller;
        use Moo;
        use Carp;
EOC
    carp $@ if $@;

    return 1;
}

1;
