use inc::Module::Install;
use strict;
use warnings;

name 'DBIx-Inline';
all_from 'lib/DBIx/Inline.pm';

build_requires 'Test::More' => '0.88';
requires 'DBI';
requires 'SQL::Abstract::More';

if ($Module::Install::AUTHOR) {
    system("pod2text lib/DBIx/Inline.pm > README")
        and die $!;
}

WriteAll();
