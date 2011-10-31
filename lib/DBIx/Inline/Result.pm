package DBIx::Inline::Result;

=head1 NAME

DBIx::Inline::Result - Class for DBIx::Inline results

=cut 

use SQL::Abstract::More;
our $sql = SQL::Abstract::More->new;

use vars qw/$sql/;

our $VERSION = '0.08';

sub method {
    my ($self, %args) = @_;

    my $key;
    for (keys %args) {
        $key = $_;
    }
    *$key = sub { $args{$key}->($self); };

    bless \*$key, 'DBIx::Inline::Result';
}

=head2 load_accessors

Creates all accessors for the current result. So instead of using hashes you can use 
subroutines.

    my $row = $rs->find([], { id => 2 });

    $row->load_accessors;
    print $row->name . "\n";
    print $row->id . "\n";

These accessors can also be used to set new values just by adding arguments.

    $row->load_accessors;
    $row->notes('Updated notes');
    $row->name('My New Name');

=cut

sub load_accessors {
    my $self = shift;
    for (keys %$self) {
        my $result = $self->{$_};
        my $table = $self->{_from};
        my $where = $self->{_where};
        my $schema = $self->{_schema};
        my $key = $_;
        *$_ = sub {
            my ($self, $a) = @_;
            if (! $a) { return $result; }
            else {
                my ($stmt, @bind) = $sql->update($table, { $key => $a }, $where);
                my $sth = $schema->prepare($stmt);
                $sth->execute(@bind);
            }
        };
        bless \*$_, 'DBIx::Inline::Result';
    }
}

=head2 accessorize

The same as load_accessors, but will only create the ones you specify. Also, it allows you 
to name the accessor to whatever you want.

    $row->accessorize(
        name    => 'long_winded_column_name',
        status  => 'user_status'
    );

    $row->name; # will fetch $row->{long_winded_column_name};

=cut

sub accessorize {
    my ($self, %args) = @_;

    for (keys %args) {
        my $result = $self->{$args{$_}};
        *$_ = sub { return $result; };
        bless \*$_, 'DBIx::Inline::Result';
    }
}

1;
