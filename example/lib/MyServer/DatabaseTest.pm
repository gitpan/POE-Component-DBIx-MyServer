package MyServer::DatabaseTest;

use strict qw(subs vars refs);
use warnings FATAL => 'all';

use POE;
 
sub resolve_query {
    my ($self, $query) = @_;

    my $sys_query = $self->resolve_sys_query($query);

    return $sys_query if defined $sys_query;

    if ($query eq 'select a_dummy_query') {
        return 'a_dummy_query';
    }
    return 'test_tables';
}

sub a_dummy_query {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
    my $data = $_[ARG0];

    print 'a_dummy_query '.$data."\n";
   	
    $self->send_results(['a_dummy_query'],
        [['a_dummy_query'],['a_dummy_query']]); 	

}


1;
