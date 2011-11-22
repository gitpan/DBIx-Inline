package DBIx::Inline::ResultSet;

=head1 NAME

DBIx::Inline::ResultSet - Methods for searching and altering tables

=cut
use SQL::Abstract::More;

our $sql = SQL::Abstract::More->new;
use vars qw/$sql/;

our $VERSION = '0.13';

=head2 fetch

Fetches the results for the entire resulset

=cut

sub fetch {
    my $self = shift;

    return $self->{result}
}

=head2 count

Returns the number of rows found

=cut

sub count {
    my $self = shift;

    return scalar @{$self->{result}};
}

=head2 all

Returns all rows in a table as a resultset

    my $rs = $schema->resultset('Users')->all;

=cut

sub all {
    my $self = shift;

    return $self->search([], {});
}

=head2 first

Get the first result from a resultset

=cut

sub first {
    my $self = shift;

    return bless $self->{result}->[0], 'DBIx::Inline::Result';
}

=head2 last

Get the last result from a resultset

=cut

sub last {
    my $self = shift;

    return bless $self->{result}->[ scalar(@{$self->{result}}-1) ], 'DBIx::Inline::Result';
}

=head2 next

A simple iterator to loop through a resultset. Each 
returned result will be returned as a Result.

    while(my $row = $result->next) {
        print $row->{name};
    }

=cut

sub next {
    my $self = shift;
    if (! exists $self->{_it_pos}) {
        $self->{_it_pos} = 0;
        $self->{_it_max} = scalar @{$self->{result}};
    }
    my $pos = $self->{_it_pos};
    $self->{_it_pos}++;
    if ($self->{_it_pos} > $self->{_it_max}) {
        delete $self->{_it_pos};
        delete $self->{_it_max};
        return undef;
    }
    return bless $self->{result}->[$pos], 'DBIx::Inline::Result';
}

=head2 primary_key

Sets the primary key for the current ResultSet

    $rs->primary_key('id');

=cut

sub primary_key {
    my ($self, $key) = @_;

    return 0 if ! $key;
    
    $self->{primary_key} = $key;
    return $self;
}

=head2 search

Access to the SQL SELECT query. Returns an array with the selected rows, which contains a hashref of values.
First parameter is an array of what you want returned ie: SELECT this, that
If you enter an empty array ([]), then it will return everything ie: SELECT *
The second parameter is a hash of keys and values of what to search for.

    my $res = $resultset->search([qw/name id status/], { status => 'active' });

    my $res = $resultset->search([], { status => 'disabled' });
    
    my $res = $resultset->search([], { -or => [ name => 'Test', name => 'Foo' ], status => 'active' });

    my $res = $resultset->search([],
        { status => 'active' },
        {
            order => ['id'],
            rows => 10,
        }
    );

=cut

sub search {
    my ($self, $fields, $c, $order) = @_;
    if (scalar @$fields == 0) { push @$fields, '*'; }
    if (exists $self->{where}) {
        for (keys %{$self->{where}}) {
            $c->{$_} = $self->{where}->{$_};
        }
    }

    $order->{rows}
        if exists $self->{rows};
    $order->{page}
        if exists $self->{page};

    my %args;
    $args{-columns} = $fields;
    $args{-from} = $self->{table};
    $args{-where} = $c;
    $args{-order_by} = $order->{order} if exists $order->{order};
    if (exists $order->{rows}) {
        if (exists $order->{page}) {
            $args{-page_size} = $order->{rows};
        }
        else { $args{-limit} = $order->{rows}; }
    }
    $args{-page_index} = $order->{page} if exists $order->{page};
    my ($stmt, @bind) = $sql->select(
        %args,
    );
    #my ($stmt, @bind) = $sql->select($self->{table}, $fields, $c);
    my ($wstmt, @wbind) = $sql->where($c);
        
    my $result = {
        dbh    => $self->{dbh},
        result => $self->{dbh}->selectall_arrayref($stmt, { Slice => {} }, @bind),
        stmt   => $wstmt,
        bind   => \@wbind,
        where  => $c,
        table  => $self->{table},
        primary_key => $self->{primary_key},
        r           => 'DBIx::Inline::Result',
        rs          => __PACKAGE__,
    };
    $result->{rows} = $order->{rows}
        if exists $order->{rows};
    
    $result->{page} = $order->{page}
        if exists $order->{page};

    return bless $result, __PACKAGE__;
}

sub find {
    my ($self, $fields, $c) = @_;
    if (scalar @$fields == 0) { push @$fields, '*'; }
    my ($stmt, @bind) = $sql->select(
        -columns => $fields,
        -from    => $self->{table},
        -where   => $c,
        -limit   => 1
    );
    my ($wstmt, @wbind) = $sql->where($c);
    my $result = $self->{dbh}->selectall_arrayref($stmt, { Slice => {} }, @bind)->[0];
    $result->{_where} = $c;
    $result->{_from} = $self->{table};
    $result->{_schema} = $self->schema;
    return bless $result, 'DBIx::Inline::Result';
}

=head2 insert

Inserts a new record.

    my $user = $resultset->insert({name => 'Foo', user => 'foo_bar', pass => 'baz'});
    $user->load_accessors;
    print $user->name . "\n";
    print "Last inserted primary key: " . $resultset->insert_id . "\n";
=cut

sub insert {
    my ($self, $c) = @_;
   
    die "Cannot insert without primary key\n"
        if ! exists $self->{primary_key};
 
    my ($stmt, @bind) = $sql->insert($self->{table}, $c);
    my $sth = $self->{dbh}->prepare($stmt);
    my $result = $sth->execute(@bind);

    my $res = $self->search([], $c);
    $c->{id} = $self->insert_id;
    ($stmt, @bind) = $sql->select($self->{table}, ['*'], $c);
    
    if ($res->count) {
        my $result = $self->{dbh}->selectall_arrayref($stmt, { Slice => {} }, @bind)->[0];
        $result->{_where} = $c;
        $result->{_from} = $self->{table};
        $result->{_schema} = $self->schema;
        
        return bless $result, 'DBIx::Inline::Result';
    }
    else { return 0; }    
}

=head2 update

Updates the current result using the hash specified

    my $res = $dbh->resultset('foo_table')->search([], { id => 5132 });
    if ($res->update({name => 'New Name'})) {
        print "Updated!\n";
    }

=cut

sub update {
    my ($self, $fieldvals) = @_;

    my ($stmt, @bind) = $sql->update($self->{table}, $fieldvals, $self->{where});
    my $sth = $self->{dbh}->prepare($stmt);
    my %args;
    $args{-columns} = ['*'],
    $args{-from}    = $self->{table},
    $args{-where}   = $self->{where},
    $args{-limit}   = $self->{rows}
        if exists $self->{rows};

    if ($sth->execute(@bind)) {
        my ($sstmt, @sbind) = $sql->select(
            %args,
        );
        my $rs = {
            dbh    => $self->{dbh},
            where  => $self->{where},
            table  => $self->{table},
            result => $self->{dbh}->selectall_arrayref($sstmt, { Slice => {} }, @sbind),
            primary_key => $self->{primary_key},
            r       => 'DBIx::Inline::Result',
            rs      => __PACKAGE__,
        };
        return bless $rs, __PACKAGE__;
    }
    else { return 0; }
}

=head2 insert_id

Gets the primary key value of the last inserted row. It will require the primary key to be set, though

=cut

sub insert_id {
    my ($self) = @_;

    if (! exists $self->{primary_key}) {
        warn "Can't call insert_id on result when no primary_key was defined in the ResultSet";
        return 0;
    }
    if (exists $self->{result}->[scalar(@{$self->{result}})-1]->{$self->{primary_key}}) {
        return $self->{result}->[scalar(@{$self->{result}})-1]->{$self->{primary_key}};
    }

    return 0;
}

=head2 delete

Drops the records in the current search result

    my $res = $resultset->search([], { id => 2 });
    $res->delete; # gone!

=cut

sub delete {
    my ($self) = @_;

    my ($stmt, @bind) = $sql->delete(-from => $self->{table}, -where => $self->{where});

    my $sth = $self->{dbh}->prepare($stmt);
    $sth->execute(@bind);
}

=head2 method

Creates a ResultSet method on the fly. Use it to create accessors, or shortcuts

    $rs->method(is_active => sub {
        return shift->search([], { account_status => 'active' });
    });

    print "Rows: " . $rs->is_active->count . "\n";

=cut

sub method {
    my ($self, $name, $sub) = @_;
    *$name = sub { $sub->(@_) };
    *{"DBIx::Inline::ResultSet::$name"} = \*$name;
}

sub schema {
    my $self = shift;

    return $self->{dbh};
}

=head2 search_join

Performs a SQL JOIN to fetch "related" records.
Say you want to find what books belong to what author. We want to find books matching author ID 2.

    my $authors = $dbi->model('Authors')->table('authors');
    $authors->search_join([], { authors => 'books', on => [ qw(id author_id) ] }, { id => 2 });

=cut

sub search_join {
    my ($self, $fields, $args, $where) = @_;

    my ($table1,$table2,$on);
    if (scalar @$fields == 0) { $fields = '*'; }
    else { $fields = join q{,}, @$fields; }
    
    for (keys %$args) {
        unless ($_ eq 'on') {
            $table1 = $_;
            $table2 = $args->{$_};
        }
        
        if ($_ eq 'on') {
            $on = $args->{$_};
        }
    }

    my ($w_key, $w_val);
    if ($where) {
        if (scalar keys %$where > 0) {
            for (keys %$where) {
                $w_key = $_;
                $w_val = $where->{$_};
            }
        }
    }
    
    my $stmt = "SELECT $fields FROM $table1 AS a INNER JOIN $table2 AS b ON ( a.$on->[0] = b.$on->[1] )";
    $stmt .= " WHERE a.$w_key = $w_val"
        if (scalar keys %$where > 0);
    
    my $result = {
        dbh    => $self->{dbh},
        result => $self->{dbh}->selectall_arrayref($stmt, { Slice => {} }),
        table  => $self->{table},
        primary_key => $self->{primary_key},
        r       => 'DBIx::Inline::Result',
        rs      => __PACKAGE__,
    };
    return bless $result, 'DBIx::Inline::ResultSet'; 
}

1;
