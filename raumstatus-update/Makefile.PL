use 5.014;
use strict;
use warnings FATAL => 'all';
use inc::Module::Install;

name     'RaumZeitLabor-Status-Update';
all_from 'lib/RaumZeitLabor/Status/Update.pm';
author   q{Maik Fischer <maikf@qu.cx>};
license  'bsd';

perl_version 5.014;

tests_recursive('t');

resources (
   #homepage   => 'http://yourwebsitehere.com',
   #IRC        => 'irc://irc.perl.org/#RaumZeitLabor-Status-Update',
   license    => 'http://www.opensource.org/licenses/BSD-3-Clause',
   #repository => 'git://github.com/Maik Fischer/RaumZeitLabor-Status-Update.git',
   bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=RaumZeitLabor-Status-Update',
);

configure_requires (
   'Module::Install' => 0,
);

build_requires (
   'Test::More' => 0,
);

requires (
   #'ABC'              => 1.6,
   #'Foo::Bar::Module' => 5.0401,
);

install_as_cpan;
auto_install;
WriteAll;
