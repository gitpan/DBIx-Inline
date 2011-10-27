package DBIx::Inline::Result;

=head1 NAME

DBIx::Inline::Result - Class for DBIx::Inline results

=cut 

our $VERSION = '0.03';

sub method {
    my ($self, %args) = @_;

    my $key;
    for (keys %args) {
        $key = $_;
    }
    *$key = sub { $args{$key}->($self); };

    bless \*$key, 'DBIx::Inline::Result';
}

1;
