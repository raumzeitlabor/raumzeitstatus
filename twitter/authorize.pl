#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab

use strict;
use warnings;
use v5.10;
use Net::Twitter;

my $nt = Net::Twitter->new(
  traits          => ['API::REST', 'OAuth'],
  consumer_key    => 'FIRST-REGISTER-APP-AT-twitter.com',
  consumer_secret => 'FIRST-REGISTER-APP-AT-twitter.com'
);

# The client is not yet authorized: Do it now
say "Authorize this app at ", $nt->get_authorization_url, " and enter the PIN#";

my $pin = <STDIN>; # wait for input
chomp $pin;

my($access_token, $access_token_secret, $user_id, $screen_name) = $nt->request_access_token(verifier => $pin);
say "access token = $access_token";
say "token secret = $access_token_secret";
