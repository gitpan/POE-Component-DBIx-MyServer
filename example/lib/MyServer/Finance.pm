package MyServer::Finance;

use strict qw(subs vars refs);
use warnings FATAL => 'all';

use POE;
use Finance::Quote;
use Data::Dumper;
 
sub resolve_query {
    my ($self, $query) = @_;

#    my $sys_query = $self->resolve_sys_query($query);
#    return $sys_query if defined $sys_query;

    return 'finance_query';
}

sub finance_query {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
    my $data = $_[ARG0];

    print 'a_dummy_query '.$data."\n";
#   	

   my $q = Finance::Quote->new;

   $q->timeout(60);

   $q->set_currency("EUR");  # Return all info in Euros.

   $q->require_labels(qw/price date high low volume/);


   my %quotes  = $q->fetch("nasdaq",qw/MSFT YHOO/);


#    print Dumper(%quotes);


    print "The price of MSFT is ".$quotes{"MSFT","price"};

    $self->send_results(['a_dummy_query'],
        [['a_dummy_query'],['a_dummy_query']]); 	


    

}


1;
