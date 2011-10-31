package DBIx::Inline::Result;

=head1 NAME

DBIx::Inline::Result - Class for DBIx::Inline results

=cut 

our $VERSION = '0.05';

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

=cut

sub load_accessors {
    my $self = shift;
    for (keys %$self) {
        my $result = $self->{$_};
        *$_ = sub { return $result; };
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
