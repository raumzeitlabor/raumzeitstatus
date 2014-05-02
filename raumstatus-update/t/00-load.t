#!perl -T
use 5.014;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'raumstatusd' ) || print "Bail out!\n";
}

diag( "Testing raumstatusd $raumstatusd::VERSION, Perl $], $^X" );
