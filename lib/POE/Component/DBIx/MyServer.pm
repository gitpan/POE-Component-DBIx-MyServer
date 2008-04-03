package POE::Component::DBIx::MyServer;

use strict qw(subs vars refs);
use warnings;

our $VERSION = "0.01_07";

use POE;
use POE::Kernel;
use POE qw(Component::Server::TCP);
use POE::Component::DBIx::MyServer::Client;
use POE::Filter::Block;
use Socket qw(INADDR_ANY inet_ntoa inet_aton AF_INET AF_UNIX PF_UNIX);
use Errno qw(ECONNABORTED ECONNRESET);
use Carp qw( croak );
use Class::Inspector;
use Module::Find;
use Data::Dumper;

use Time::HiRes qw( gettimeofday tv_interval);

BEGIN {
	if ( ! defined &DEBUG ) {
		eval "sub DEBUG () { 0 }";
	}
}

my $server_class;

sub spawn {
	my ($class, %opt) = @_;
	$server_class = $class;
	my ( $alias, $address, $port, $hostname, $got_query );

	if ( exists $opt{'alias'} and defined $opt{'alias'} and length( $opt{'alias'} ) ) {
		$alias = $opt{'alias'};
		delete $opt{'alias'};
	}

	if ( exists $opt{'port'} and defined $opt{'port'} and length( $opt{'port'} ) ) {
		$port = $opt{'port'};
		delete $opt{'port'};
	}
    else {
		croak( 'port is required to create a new POE::Component::Server::SimpleHTTP instance!' );
	}

	if ( exists $opt{'hostname'} and defined $opt{'hostname'} and length( $opt{'hostname'} ) ) {
		$hostname = $opt{'hostname'};
		delete $opt{'hostname'};
	} else {
		if ( DEBUG ) {
			print 'Using Sys::Hostname for hostname';
		}

		require Sys::Hostname;
		$hostname = Sys::Hostname::hostname();

		if ( exists $opt{'hostname'} ) {
			delete $opt{'hostname'};
		}
	}

    my $data = {
        'alias'		   =>	$alias,
        'address'	   =>	$address,
        'port'		   =>	$port,
        'hostname'	   =>	$hostname,
        'query_handlers' => $opt{'query_handlers'},
    };
    my $self = bless $data, $class;

    my $acceptor_session_id = POE::Component::Server::TCP->new(
        Port          => $port,
        Address       => $address,
        Hostname      => $hostname,
        Domain        => AF_INET,
        Alias         => $alias,
        Started       => \&_server_start,
        Acceptor      => \&_accept_client,
        SessionParams => [
            heap            => {
                max_processes   => $opt{'max_processes'},
            },
        ],
    );

	return $self;
}

sub _server_start {
    my ( $kernel, $session, $heap ) = @_[ KERNEL, SESSION, HEAP];

    warn "Server $$ has begun listening \n";

    if ($heap->{max_processes})  {

        print "About to fork .. \n";

        $kernel->sig( CHLD => "got_sig_chld" );
        $kernel->sig( INT  => "got_sig_int" );

        $heap->{children}   = {};
        $heap->{is_a_child} = 0;

        my $current_children = keys %{ $heap->{children} };
        for ( $current_children + 2 .. $heap->{max_processes} ) {

            warn "Server $$ is attempting to fork.\n";

            my $pid = fork();

            unless ( defined($pid) ) {
                warn( "Server $$ fork failed: $!\n");
                return;
            }

            # Parent.  Add the child process to its list.
            if ($pid) {
                $heap->{children}->{$pid} = 1;
                next;
            }

            # Child.  Clear the child process list.
            warn "Server $$ forked successfully.\n";
            $heap->{is_a_child} = 1;
            $heap->{children}   = {};
            return;
        }
    }
}


sub _accept_client {
    my ( $kernel, $session, $heap ) = @_[ KERNEL, SESSION, HEAP];
    my ($socket, $remote_addr, $remote_port) = @_[ARG0, ARG1, ARG2];

    my $domain  = AF_INET;
    my $query_handlers = $heap->{'query_handlers'};

    my $client = POE::Component::DBIx::MyServer::Client->new({
        server_class    => $server_class
    });

    my $accept_session_id = POE::Session->create(
        object_states => [
            $client =>  { tcp_server_got_input => 'handle_client_input' }
        ],
        inline_states => {
            _start => sub {
                my ( $kernel, $session, $heap ) = @_[KERNEL, SESSION, HEAP];

                $heap->{shutdown} = 0;

                if (length($remote_addr) == 4) {
                    $heap->{remote_ip} = inet_ntoa($remote_addr);
                }
                else {
                    $heap->{remote_ip} =
                    Socket6::inet_ntop($domain, $remote_addr);
                }

                $heap->{remote_port} = $remote_port;

                $heap->{client} = POE::Wheel::ReadWrite->new(
                    Handle       => $socket,
                    Driver       => POE::Driver::SysRW->new(),
                    Filter       => POE::Filter::Block->new(
                        LengthCodec => [ \&_length_encoder, \&_length_decoder ]
                    ),
                    InputEvent   => 'tcp_server_got_input',
                    ErrorEvent   => 'tcp_server_got_error',
                    #AutoFlush    => 1,
                );
                $client->wheel($heap->{client});
                $client->session_id($session->ID);
                $client->session($session);

                # register system states
                my @methods = Class::Inspector->methods(
                    'POE::Component::DBIx::MyServer::Client',
                    'expanded',
                    'public'
                );

                foreach my $method (@{ $methods[0] }) {
                    my ($full, $class, $method, undef ) = @{ $method };
                    next if $method =~ /^send_/
                            or $method eq 'write'
                            or $method eq 'new_definition';
                    if ($class eq 'POE::Component::DBIx::MyServer::Client') {
                        # too much stuff is registered here !!!
                        # need to mark private some stuff ...
                        $session->_register_state($method, $client);
                    }
                }

                $client->handle_client_connect(@_);
            },
            _child  => sub { },

            #tcp_server_got_input => sub {
            #  return if $_[HEAP]->{shutdown};
            #  $_[KERNEL]->yield('handle_client_input', $_[ARG0]);
            #  undef;
            #},
            tcp_server_got_error => sub {
              DEBUG and warn(
                "$$:  child Error ARG0=$_[ARG0] ARG1=$_[ARG1]"
              );
              unless ($_[ARG0] eq 'accept' and $_[ARG1] == ECONNABORTED) {
                $client->handle_client_error(@_);
                if ($_[HEAP]->{shutdown_on_error}) {
                  $_[HEAP]->{got_an_error} = 1;
                  $_[KERNEL]->yield("shutdown");
                }
              }
            },

            shutdown => sub {
              DEBUG and warn "$$:  child Shutdown";
              my $heap = $_[HEAP];
              $heap->{shutdown} = 1;
              if (defined $heap->{client}) {
                if (
                  $heap->{got_an_error} or
                  not $heap->{client}->get_driver_out_octets()
                ) {
                  DEBUG and warn "$$:  child Shutdown, callback";
                  $client->handle_client_disconnect(@_);
                  delete $heap->{client};
                }
              }
            },
#        _stop => sub {
#          ## concurrency on close
#          DEBUG and warn(
#            "$$:  _stop accept_session = $accept_session_id"
#          );
#          if( defined $accept_session_id ) {
#            $_[KERNEL]->call( $accept_session_id, 'disconnected' );
#          }
#          else {
#            # This means that the Server::TCP was shutdown before
#            # this connection closed.  So it doesn't really matter that
#            # we can't decrement the connection counter.
#            DEBUG and warn(
#              "$$: $_[HEAP]->{alias} Disconnected from a connection ",
#              "without POE::Component::Server::TCP parent"
#            );
#          }
#          return;
#        },
        },
    #    options => {trace => 1,
    #debug => 1,}
    );
}


sub _length_encoder {
    return;
}

sub _length_decoder {
   my $stuff = shift;

   if (length($$stuff) > 1) {
      return length($$stuff);
   }
   else {
      return 1;
   }
}

sub handle_client_disconnect {
   my ( $kernel, $session, $heap ) = @_[ KERNEL, SESSION, HEAP];

   print "handle_client_disconnect"."\n" if DEBUG;
}

=head1 NAME

POE::Component::DBIx::MyServer - A pseudo mysql POE server

=head1 DESCRIPTION

This modules helps building a server that can communicates
with mysql clients.

Experimental now.

There is a small proxy that actually connect to another mysql server
via DBI and returns the result of sql requests. It actually works
not very correctly since a few mysql specific stuff are not handled
properly and since it return stuff from selects.

=head1 SYNOPSYS

First you create a server subclass that will redefine the change_db method.

    package MyServer;

    use POE;
    use base 'POE::Component::DBIx::MyServer';

    sub change_db {
        my $class = shift;
        my ($client, $data) = @_;

        if (Class::Inspector->installed($class."::".$data)) {
            $client->isa($class."::".$data);
        }
    }

In the example the MyServer shipped uses various perl classes as DB handlers.
Maybe it's possible to deal with it differently and change_db in some other way.

Then you can create various classes (that subclass the PoCo::DBIx::MyServer::Client
class) that will behave as databases in your mysql server.

    package MyServer::HelloWorld;

    use POE;

    sub resolve_query {
        my ($self, $query) = @_;
        my $event = $self->resolve_sys_query($query);

        if ($event) {
            return $event;
        }
        else {
            return 'hello_world_event';
        }
    }

    sub hello_world_event {
        my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
        my $data = $_[ARG0];

        $self->send_results(['column1'], [['Hello World from a perl mysql DB !']]);
    }

    1;

In those classes you have to redefine the resolver method in which you can resolve
queries to events name (by returning the event name). Then you implement events as
methods (with special POE stuff, check the samples).

Make sure to resolve the system queries otherwise you won't be able to connect to
the server in the first place.

Then you can use the send_results method (which is a wrapper around _send_definitions
and _send_rows) to send data to the client.

There are also a bunch of other methods to send empty resultsets or ok for queries
that don't return results.

=head1 AUTHORS

Eriam Schaffter, C<eriam@cpan.org> and original work done by Philip Stoev in the DBIx::MyServer module.

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
