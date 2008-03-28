use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'POE::Component::DBIx::MyServer',
    AUTHOR        => 'Eriam Schaffter <eriam@cpan.org>',
    VERSION_FROM  => 'lib/POE/Component/DBIx/MyServer.pm',
    ABSTRACT_FROM => 'lib/POE/Component/DBIx/MyServer.pm',
    LICENSE       => 'perl',
    PL_FILES      => {},
    PREREQ_PM     => {
        'Test::More' => 0,
        'version'    => 0,
        'POE'               => '0.38',
        'Module::Find'      => '0.06',
        'Class::Inspector'  => 0,
        'Module::Reload'    => 0,
        'Catalyst'          => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'POE-Component-*' },
);

