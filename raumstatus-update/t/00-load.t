#!perl -T
use 5.014;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'RaumZeitLabor::Status::Update' ) || print "Bail out!\n";
}

diag( "Testing RaumZeitLabor::Status::Update $RaumZeitLabor::Status::Update::VERSION, Perl $], $^X" );
