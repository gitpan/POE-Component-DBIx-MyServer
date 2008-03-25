package MyServer;
use strict;

use POE;
use base 'POE::Component::DBIx::MyServer';

sub change_db {
    my $class = shift;
    my ($client, $data) = @_;

    if (Class::Inspector->installed($class."::".$data)) {
        $client->isa($class."::".$data);
    }
    else {
        print "I can't load the DB class ".$class."::".$data." doh \n";
    }

}

1;
