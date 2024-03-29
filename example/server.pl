use POE;
use lib './lib/';
use MyServer;

MyServer->spawn(
    'alias'             => 'mysql',
    'port'              => 23306,
    'hostname'          => 'localhost',
    'max_processes'     => 4,
);

POE::Kernel->run();
