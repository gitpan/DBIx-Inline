package DBIx::Inline;

use DBI;

use base qw/
    DBIx::Inline::Schema
    DBIx::Inline::ResultSet
    DBIx::Inline::Result
/;

$DBIx::Inline::VERSION = '0.09';
our $global = {};

=head1 NAME

DBIx::Inline - DBIx::Class without the class.

=head1 DESCRIPTION

This module is yet another interface to DBI. I liked how L<DBIx::Class> works, separating the results from the resultsets, the resultsets from the results and the schema from everything else. 
It's tidy, easy to follow and works a treat. I also liked how you can "reuse" queries in resultsets and results without typing them out again and again. However, when I wanted to work on a small 
project I found DBIx::Class a little slow and didn't want to keep setting up the classes for it to work. DBIx::Inline attempts follow the way DBIx::Class does things, but more "inline". You 
still get the reusable queries, Results and ResultSets, but without all the classes to setup. You do lose a lot of functionality that you get with DBIx::Class, but that's not what DBIx::Inline is 
really about. I wanted it to be faster and not hold your hand with everything, yet still be easy enough to use. 
It's still possible to have accessors and Result/ResulSet methods, but they are created on-the-fly with B<method>. Also, you can automatically create all accessors for a result using B<load_accessors>.
DBIx::Inline is great for small projects that do not require a lot of customisation, but for anything else I'd highly recommend B<DBIx::Class>.

=head1 SYNOPSIS

    package main;

    use base 'DBIx::Inline';

    my $schema = main->connect(
        dbi => 'SQLite:test.db'
    );

    my $rs = $schema->resultset('my_user_table');
    
    # create an accessor
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

This method needs a lot of work, but it functions at the moment. And I like it. 
Instead of calling the connect method in every file, you can share the model by putting it in 
inline.yml (which it looks for by default), or setting ->config.

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
    bless $dbhx, 'DBIx::Inline::Schema';
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

=cut

sub config {
    use vars qw/$global/;
    my ($class, $file) = @_;
    
    if ($file) { $global->{config} = $file; }
    else { return $global->{config}||0; }
}

    

=head1 AUTHOR

Brad Haywood <brad@geeksware.net>

=head1 LICENSE

Same license as Perl

=cut

1;
