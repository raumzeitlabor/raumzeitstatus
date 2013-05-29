#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'RaumZeitLabor::RaumStatus' ) || print "Bail out!\n";
}

diag( "Testing RaumZeitLabor::RaumStatus $RaumZeitLabor::RaumStatus::VERSION, Perl $], $^X" );
