package DBIx::Inline;

use DBI;

use base qw/
    DBIx::Inline::Schema
    DBIx::Inline::ResultSet
    DBIx::Inline::Result
/;

$DBIx::Inline::VERSION = '0.03';

=head1 NAME

DBIx::Inline - DBIx::Class without the class.

=head1 DESCRIPTION

An "inline" version to DBIx::Class, but by no means an alternative or its equal in any sense. Due to boredom and too many classes lying around 
I put together DBIx::Inline to try and emulute some of DBIx::Class' cool features into one script. It's far from it, but 
I believe it's an OK work in progress. You can still create accessors, but they are done on the fly using DBIx::Inline::ResultSet->method(name => sub { ... }).
Results have ->method, but you need to include it in an iterator for it to work properly.. ie

    while(my $row = $rs->next) {
        $row->method(name => sub { return shift->{the_name_column}; });
        print $row->name . "\n";
    }

Check out the synopsis for more info on how to use DBIx::Inline.

=head1 SYNOPSIS

    package main;

    use base 'DBIx::Inline';

    my $schema = main->connect(
        dbi => 'SQLite:test.db'
    );

    my $rs = $schema->resultset('my_user_table');
    
    # create an accessor
    $rs->method(not_active => sub {
        return shift->search([], { account_status => 'disabled' }, { order => ['id'], limit => 5 });
    });

    # chain the custom resultset method with a core one (count)
    print "Rows returned: " . $rs->not_active->count . "\n";

    # make the records in the resultset active
    # will return a resultset with the updated data
    my $new_rs = $rs->update({account_status => 'active'});

=cut

=head2 connect

Creates the Schema instance using the hash specified. Currently only dbi is mandatory, 
which tells DBI which engine to use (SQLite, Pg, etc).
If you're using SQLite there is no need to set user or pass.

    my $dbh = DBIx::Inline->connect(
        dbi => 'SQLite:/var/db/test.db',
    );

    my $dbh = DBIx::Inline->connect(
        dbi  => 'Pg:host=myhost;dbname=dbname',
        user => 'username',
        pass => 'password',
    );

=cut

sub connect {
    my ($class, %args) = @_;

    my $dbh = DBI->connect(
        'dbi:' . $args{dbi},
        $args{user}||undef,
        $args{pass}||undef,
        { PrintError => 0 }
    ) or do {
        warn 'Could not connect to database: ' . $DBI::errstr;
        return 0;
    };

    my $dbhx = { dbh => $dbh, schema => $class };
    bless $dbhx, 'DBIx::Inline::Schema';
}

=head1 AUTHOR

Brad Haywood <brad@geeksware.net>

=head1 LICENSE

Same license as Perl

=cut

1;
