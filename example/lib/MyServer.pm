package MyServer;
use strict;

use POE;
use base 'POE::Component::DBIx::MyServer';

sub change_db {
    my $class = shift;
    my ($client, $data) = @_;

    $client->isa('MyServer::DatabaseTest');

}


1;
