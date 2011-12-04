package DBIx::Inline;

use Goose qw/:Class/;
use DBI;

extends qw/
    DBIx::Inline::Schema
    DBIx::Inline::ResultSet
    DBIx::Inline::Result
/;

$DBIx::Inline::VERSION = '0.17';
our $global = {};

=head1 NAME

DBIx::Inline - DBIx::Class without the class.

=head1 DESCRIPTION

This module is yet another interface to DBI. I like how L<DBIx::Class> works, separating the results from the resultsets, the resultsets from the results and the schema from everything else. 
It's tidy, easy to follow and works a treat. I also like how you can "reuse" queries in resultsets and results without typing them out again and again. However, when I wanted to work on a small 
project I found DBIx::Class a little slow and didn't want to keep setting up the classes for it to work. DBIx::Inline attempts follow the way DBIx::Class does things, but more "inline". You 
still get the reusable queries, Results and ResultSets, but without all the classes to setup. You do lose a lot of functionality that you get with DBIx::Class, but that's not what DBIx::Inline is 
really about. I wanted it to be faster and not hold your hand with everything, yet still be easy enough to use. 
It's still possible to have accessors and Result/ResulSet methods, but they are created on-the-fly with B<method>. Also, you can automatically create all accessors for a result using B<load_accessors>.
DBIx::Inline is great for small projects that do not require a lot of customisation, but for anything else I'd highly recommend B<DBIx::Class>.

=head1 SYNOPSIS

    package MyDB;

    use base 'DBIx::Inline';

    my $rs = MyDB->model('Foo')->all; # Read up about models to see what this does
    # or..
    my $rs = MyDB->sqlite('/some/sqlite.db')->resultset('users')->all;
    # or..
    my $rs = MyDB->connect(
        dbi => 'SQLite:/some/sqlite.db',
    );
    $rs = $rs->resultset('users');
    
    # create a resultset method on-the-fly
    $rs->method(not_active => sub {
        return shift->search([], { account_status => 'disabled' }, { order => ['id'], rows => 5 });
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
    use vars qw/$global/;
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

Models make your life easier when you need to reuse a specific connection. You can even go so far as specifying a ResultSet to use by default.
By default, DBIx::Inline will look for inline.yml, unless you have configured a different models file with C<config('file.yml')>.
The syntax is very basic and uses a simple YAML file, making it easy to move around if you need to.

    # inline.yml
    ---
    Foo:
      connect: 'SQLite:foo.db'
    
    AnotherSchema:
      connect: 'Pg:host=localhost;dbname=foo'
      user: 'myuser'
      pass: 'pass'

    WithResultSet:
      connect: 'SQLite:test.db'
      resultset: 'users'
 
    # test.pl
    package main;
  
    my $rs = main->model('AnotherSchema')->resultset('the_table');
    my $rs2 = main->model('WithResultset'); # that's all we need!
    while(my $row = $rs2->next) {
        $row->load_accessors;
        print $row->name;
    }

As of 0.15 you can now use related tables. It basically does a search_join in a convenient accessor for you. The accessor search is *very* limited, allowing only one key.

    # inline.yml
    AnotherSchema:
      connect: 'Pg:host=localhost;dbname=foo'
      user: 'myuser'
      pass: 'pass'
      related:
        authors: 'id <-> books(authors_id)'

    # then in your code
    my $rs = $c->model('AnotherSchema')->resultset('authors');
    my $books = $rs->authors({ id => 3 }); # search for all books by author with id of 3

    # now use it as any normal resultset
    while( my $row = $books->next ) {
        $row->load_accessors;
        print $row->book_title;
    }

=cut

sub model {
    use vars qw/$global/;
    my ($class, $model) = @_;
   
    my $file = $global->{config}||'inline.yml'; 
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
    
    if (exists $yaml->{$model}->{resultset}) {
        
        bless $dbhx, 'DBIx::Inline::Schema';
        my $rs = $yaml->{$model}->{resultset};
        # get columns from model file?
        
        return $dbhx->resultset($rs)->search([], {});
    }

    if (exists $yaml->{$model}->{related}) {
        if (scalar keys %{$yaml->{$model}->{related}} > 0) {
            foreach my $relate (keys %{$yaml->{$model}->{related}}) {
                my $relation = $yaml->{$model}->{related}->{$relate};
                if ($relation =~ /^(\w+)\s*?<\->\s*?(\w+)\s*?\(\s*?(\w+)\s*?\)$/) {
                    my $relate_table = $2;
                    my $relation_id = $1;
                    my $related_id = $3;
                    DBIx::Inline::ResultSet->create( $relate => sub {
                        my ($self, $args) = @_;
                        return $self->search_join([], { $relate => $relate_table, on => [$relation_id, $related_id] }, $args||{} );
                    });
                }
            }
        }
    }
    
    bless $dbhx, 'DBIx::Inline::Schema';
}

=head2 sqlite

Initially load a SQLite database (file). Instead of going through models or dbi string we can just call C<sqlite('file')>.

    package main;
    
    use base 'DBIx::Inline';

    my $schema = main->sqlite('/path/to/db.db')->resultset('users');

=cut

sub sqlite {
    my ($class, $file, $args) = @_;

    $args = {}
        if ! $args;
    # we don't care about making sure the file exists
    # because with sqlite we can just create a new one!
    my $dbh = DBI->connect(
        "dbi:SQLite:$file",
        $args,
    );

    my $dbx = { dbh => $dbh, schema => $class };
    bless $dbx, 'DBIx::Inline::Schema';
}

=head2 config

Sets the location of the configuration (file with the models. The Schema models.. not girls).
This allows you to have the file anywhere on your system and you can rename it to anything.

    # /var/schema/myschemas.yml
    Foo:
      connect: 'SQLite:/var/db/mydb.db'
    
    # /scripts/db.pl
    package main;

    use base 'DBIx::Inline';

    main->config ('/var/schema/myschemas.yml');
    my $schema = main->model('Foo');

You can even chain C<config> to C<model> if you want.

    my $schema = main->config('/var/schema/myschemas.yml')->model('Foo');


=cut

sub config {
    use vars qw/$global/;
    my ($class, $file) = @_;
    
    if ($file) { $global->{config} = $file; return $class }
    else { return $class; }#$global->{config}||0; }
}

=head1 AUTHOR

Brad Haywood <brad@geeksware.net>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;
