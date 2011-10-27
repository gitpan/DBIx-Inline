package DBIx::Inline::Schema;
use base 'DBIx::Inline::ResultSet';

our $VERSION = '0.03';

sub resultset {
    my ($self, $table) = @_;

    my $pkg = "DBIx::Inline::ResultSet";
    $self->{resultset} = { dbh => $self->{dbh}, rs => $pkg, r => "DBIx::Inline::Result", table => $table };
    bless $self->{resultset}, "DBIx::Inline::ResultSet";
    return $self->{resultset};
}

1;
