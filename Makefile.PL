use strict;
use warnings;
use inc::Module::Install 0.91;
use Module::Install::AuthorRequires;
use Module::Install::AuthorTests;

name 'DBIx-Inline';
all_from 'lib/DBIx/Inline.pm';

build_requires 'Test::More' => '0.88';
requires 'DBI';
requires 'DBD::SQLite';
requires 'SQL::Abstract::More';

if ($Module::Install::AUTHOR) {
    system("pod2text lib/DBIx/Inline.pm > README")
        and die $!;
}

WriteAll();
