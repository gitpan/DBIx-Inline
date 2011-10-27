package DBIx::Inline::ResultSet;

=head1 NAME

DBIx::Inline::ResultSet - Methods for searching and altering tables

=cut

use SQL::Abstract::More;

our $sql = SQL::Abstract::More->new;
use vars qw/$sql/;

our $VERSION = '0.03';

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
returned result will be blessed as a Result.

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
    return 1;
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
            limit => 10,
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

    my %args;
    $args{-columns} = $fields;
    $args{-from} = $self->{table};
    $args{-where} = $c;
    $args{-order_by} = $order->{order} if exists $order->{order};
    $args{-limit} = $order->{limit} if exists $order->{limit};
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
    $result->{limit} = $order->{limit}
        if exists $order->{limit};

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
    return bless $result, 'DBIx::Inline::Result';
}

=head2 insert

Inserts a new record.

    my $insert = $resultset->insert({name => 'Foo', user => 'foo_bar', pass => 'baz'});
    if ($insert) { print "Added user!\n"; }
    else { print "Could not add user\n"; }

=cut

sub insert {
    my ($self, $c) = @_;
    
    my ($stmt, @bind) = $sql->insert($self->{table}, $c);
    my $sth = $self->{dbh}->prepare($stmt);
    my $result = $sth->execute(@bind);

    my $res = $self->search([], $c);
    ($stmt, @bind) = $sql->select($self->{table}, ['*'], $c);
    
    if ($res->count) {
        my $rs = {
            dbh    => $self->{dbh},
            where  => $c,
            table  => $self->{table},
            result => $self->{dbh}->selectall_arrayref($stmt, { Slice => {} }, @bind),
            primary_key => $self->{primary_key},
            r       => 'DBIx::Inline::Result',
            rs      => __PACKAGE__,
        };
        
        return bless $rs, 'DBIx::Inline::Result';
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
    $args{-limit}   = $self->{limit}
        if exists $self->{limit};

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
    my ($self, %args) = @_;

    my $key;
    for (keys %args) {
        $key = $_;
    }
    *$key = sub { $args{$key}->($self); };
    
    bless \*$key, 'DBIx::Inline::ResultSet';
}

1;
