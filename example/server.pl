use POE;
use lib './lib/';
use MyServer;

MyServer->spawn(
    'alias'             => 'mysql',
    'port'              => 23306,
    'hostname'          => 'localhost',
);

POE::Kernel->run();
 
