use inc::Module::Install;
use strict;
use warnings;

name 'DBIx-Inline';
all_from 'lib/DBIx/Inline.pm';

test_requires 'Test::Lite';
requires 'DBI';
requires 'DBD::SQLite';
requires 'SQL::Abstract::More';
requires 'YAML::Syck';
requires 'DateTime';

auto_install();

if ($Module::Install::AUTHOR) {
    system("pod2text lib/DBIx/Inline.pm > README")
        and die $!;
}

WriteAll();
