use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'RaumZeitLabor::RaumStatus',
    AUTHOR           => q{Maik Fischer <maikf+rzl-raumstatus@qu.cx>},
    VERSION_FROM     => 'lib/RaumZeitLabor/RaumStatus.pm',
    ABSTRACT_FROM    => 'lib/RaumZeitLabor/RaumStatus.pm',
    LICENSE          => 'Artistic_2_0',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.014,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'AnyEvent::HTTP' => 0,
        'JSON::XS' => 0,
        'Method::Signatures::Simple' => 0,
        'Moose' => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'RaumZeitLabor-RaumStatus-*' },
);
