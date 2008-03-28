package MyServer::Proxy;

use strict qw(subs vars refs);
use warnings FATAL => 'all';

use POE;
use DBI;
use Data::Dumper;

my $DBH;

sub resolve_query {
    my ($self, $query) = @_;

    my $event = $self->resolve_sys_query($query);

    if ($event) {
        print "doing $event \n";
        return $event;
    }
    elsif ($query =~ /columns_priv/ || $query =~ /db/) {
        return 'proxy_do';
    }
    return 'proxy_query';
}

sub proxy_do {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
    my $data = $_[ARG0];

    $self->_connect unless defined $DBH;

    my $results;

    eval {
        $results = $DBH->do($data);

        $self->send_ok;
    };

    if ($@) {
        $self->send_error($@); 
    }	
}

sub proxy_query {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
    my $data = $_[ARG0];

    $self->_connect unless defined $DBH;

    my $results;

    eval {
        $results = $DBH->selectall_arrayref($data);

        my @headers;

        my $sth = $DBH->prepare($data);
        if (!$sth) {
            $self->send_error($DBH->errstr); 
        }
        if (!$sth->execute) {
            $self->send_error($sth->errstr); 
        }

        my $names = $sth->{'NAME'};
        my $numFields = $sth->{'NUM_OF_FIELDS'};
        for (my $i = 0;  $i < $numFields;  $i++) {
            push @headers, $$names[$i];
        }
        
        $self->send_results(\@headers, $results);
    };

    if ($@) {
        $self->send_error($@); 
    }	
}

sub _connect {
    my ($self) = @_;

    my $dsn = "DBI:mysql:database=".$ENV{mysql_db}.";host=127.0.0.1;port=3306";

    $DBH = DBI->connect($dsn, $ENV{mysql_username}, $ENV{mysql_password});
}


1;

