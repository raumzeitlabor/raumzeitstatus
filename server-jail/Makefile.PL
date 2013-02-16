use inc::Module::Install;

name     'RaumZeitStatus';
all_from 'lib/RaumZeitLabor/Status.pm';
author   q{Simon Elsbrock <simon@iodev.org>};
license  'gpl';

build_requires 'Test::More';

requires 'EV';
requires 'Tatsumaki';
requires 'MooseX::Singleton';
requires 'JSON::XS';
requires 'Plack';
requires 'Twiggy';

install_script 'scripts/raumzeitstatus';

auto_install;

WriteAll;

