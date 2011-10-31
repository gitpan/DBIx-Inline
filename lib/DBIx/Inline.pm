package DBIx::Inline;

use DBI;

use base qw/
    DBIx::Inline::Schema
    DBIx::Inline::ResultSet
    DBIx::Inline::Result
/;

$DBIx::Inline::VERSION = '0.05';

=head1 NAME

DBIx::Inline - DBIx::Class without the class.

=head1 DESCRIPTION

An "inline" version to DBIx::Class, but by no means an alternative or its equal in any sense. Due to boredom and too many classes lying around 
I put together DBIx::Inline to try and emulute some of DBIx::Class' cool features into one script. It's far from it, but 
I believe it's an OK work in progress. You can still create accessors, but they are done on the fly using DBIx::Inline::ResultSet->method(name => sub { ... }).
Results have ->method, but the easiest way is to use $row->load_accessors, which will create methods for all of your result values (L<DBIx::Inline::Result>)
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

=head2 model

This method needs a lot of work, but it functions at the moment. And I like it. 
Instead of calling the connect method in every file, you can share the model by putting it in 
inline.yml, like so.

    # inline.yml
    ---
    Foo:
      connect: 'SQLite:foo.db'
    
    AnotherSchema:
      connect: 'Pg:host=localhost;dbname=foo'
      user: 'myuser'
      pass: 'pass'

    # test.pl
    package main;
  
    my $rs = main->model('AnotherSchema')->resultset('the_table');

=cut

sub model {
    my ($class, $model) = @_;
   
    my $file = 'inline.yml'; 
    die "Can't locate config '$file'\n"
        if ! -f $file;
    
    use YAML::Syck;

    my $yaml = LoadFile($file);
    die "No such model '$model'\n"
        if ! exists $yaml->{$model};
    
    my $dbh = DBI->connect(
        'dbi:' . $yaml->{$model}->{connect},
        $yaml->{$model}->{user}||undef,
        $yaml->{$model}->{pass}||undef,
    );

    my $dbhx = { dbh => $dbh, schema => $class };
    bless $dbhx, 'DBIx::Inline::Schema';
}
    

=head1 AUTHOR

Brad Haywood <brad@geeksware.net>

=head1 LICENSE

Same license as Perl

=cut

1;
