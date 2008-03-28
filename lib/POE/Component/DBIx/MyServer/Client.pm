package POE::Component::DBIx::MyServer::Client;

# Standard stuff to catch errors
use strict qw(subs vars refs);
use warnings FATAL => 'all';

use vars qw($VERSION @ISA);

# Initialize our version
$VERSION = '0.01_06';

use POE;
use POE::Kernel;
use Module::Find;
use Carp qw( croak );
use Class::Accessor::Fast;
use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(qw/
    username
    password
    wheel
    session_id
    session
    banner
    salt
    charset
    tid
    packet_count
    scramble
    username
    authenticated
    query_handlers
    rows_buffer
    database
    server_class
    want_db_name
/);

use Data::Dumper;

BEGIN {
	# Debug fun!
	if ( ! defined &DEBUG ) {
		eval "sub DEBUG () { 0 }";
	}
	# Our own definition of the max retries
	if ( ! defined &MAX_RETRIES ) {
		eval "sub MAX_RETRIES () { 5 }";
	}
}


use constant MYSERVER_PACKET_COUNT	=> 0;
use constant MYSERVER_SOCKET		=> 1;
use constant MYSERVER_DATABASE		=> 4;
use constant MYSERVER_THREAD_ID		=> 5;
use constant MYSERVER_SCRAMBLE		=> 6;
use constant MYSERVER_DBH		=> 7;
use constant MYSERVER_PARSER		=> 8;
use constant MYSERVER_BANNER		=> 9;
use constant MYSERVER_SERVER_CHARSET	=> 10;
use constant MYSERVER_CLIENT_CHARSET	=> 11;
use constant MYSERVER_SALT		=> 12;

use constant FIELD_CATALOG		=> 0;
use constant FIELD_DB			=> 1;
use constant FIELD_TABLE		=> 2;
use constant FIELD_ORG_TABLE		=> 3;
use constant FIELD_NAME			=> 4;
use constant FIELD_ORG_NAME		=> 5;
use constant FIELD_LENGTH		=> 6;
use constant FIELD_TYPE			=> 7;
use constant FIELD_FLAGS		=> 8;
use constant FIELD_DECIMALS		=> 9;
use constant FIELD_DEFAULT		=> 10;


#
# This comes from include/mysql_com.h of the MySQL source
#

use constant CLIENT_LONG_PASSWORD	=> 1;
use constant CLIENT_FOUND_ROWS		=> 2;
use constant CLIENT_LONG_FLAG		=> 4;
use constant CLIENT_CONNECT_WITH_DB	=> 8;
use constant CLIENT_NO_SCHEMA		=> 16;
use constant CLIENT_COMPRESS		=> 32;		# Must implement that one
use constant CLIENT_ODBC		=> 64;
use constant CLIENT_LOCAL_FILES		=> 128;
use constant CLIENT_IGNORE_SPACE	=> 256;
use constant CLIENT_PROTOCOL_41		=> 512;
use constant CLIENT_INTERACTIVE		=> 1024;
use constant CLIENT_SSL			=> 2048;	# Must implement that one
use constant CLIENT_IGNORE_SIGPIPE	=> 4096;
use constant CLIENT_TRANSACTIONS	=> 8192;
use constant CLIENT_RESERVED 		=> 16384;
use constant CLIENT_SECURE_CONNECTION	=> 32768;
use constant CLIENT_MULTI_STATEMENTS	=> 1 << 16;
use constant CLIENT_MULTI_RESULTS	=> 1 << 17;
use constant CLIENT_SSL_VERIFY_SERVER_CERT	=> 1 << 30;
use constant CLIENT_REMEMBER_OPTIONS		=> 1 << 31;

use constant SERVER_STATUS_IN_TRANS		=> 1;
use constant SERVER_STATUS_AUTOCOMMIT		=> 2;
use constant SERVER_MORE_RESULTS_EXISTS		=> 8;
use constant SERVER_QUERY_NO_GOOD_INDEX_USED	=> 16;
use constant SERVER_QUERY_NO_INDEX_USED		=> 32;
use constant SERVER_STATUS_CURSOR_EXISTS	=> 64;
use constant SERVER_STATUS_LAST_ROW_SENT	=> 128;
use constant SERVER_STATUS_DB_DROPPED		=> 256;
use constant SERVER_STATUS_NO_BACKSLASH_ESCAPES => 512;

use constant COM_SLEEP			=> 0;
use constant COM_QUIT			=> 1;
use constant COM_INIT_DB		=> 2;
use constant COM_QUERY			=> 3;
use constant COM_FIELD_LIST		=> 4;
use constant COM_CREATE_DB		=> 5;
use constant COM_DROP_DB		=> 6;
use constant COM_REFRESH		=> 7;
use constant COM_SHUTDOWN		=> 8;
use constant COM_STATISTICS		=> 9;
use constant COM_PROCESS_INFO		=> 10;
use constant COM_CONNECT		=> 11;
use constant COM_PROCESS_KILL		=> 12;
use constant COM_DEBUG			=> 13;
use constant COM_PING			=> 14;
use constant COM_TIME			=> 15;
use constant COM_DELAYED_INSERT		=> 16;
use constant COM_CHANGE_USER		=> 17;
use constant COM_BINLOG_DUMP		=> 18;
use constant COM_TABLE_DUMP		=> 19;
use constant COM_CONNECT_OUT		=> 20;
use constant COM_REGISTER_SLAVE		=> 21;
use constant COM_STMT_PREPARE		=> 22;
use constant COM_STMT_EXECUTE		=> 23;
use constant COM_STMT_SEND_LONG_DATA	=> 24;
use constant COM_STMT_CLOSE		=> 25;
use constant COM_STMT_RESET		=> 26;
use constant COM_SET_OPTION		=> 27;
use constant COM_STMT_FETCH		=> 28;
use constant COM_END			=> 29;

# This is taken from include/mysql_com.h

use constant MYSQL_TYPE_DECIMAL		=> 0;
use constant MYSQL_TYPE_TINY		=> 1;
use constant MYSQL_TYPE_SHORT		=> 2;
use constant MYSQL_TYPE_LONG		=> 3;
use constant MYSQL_TYPE_FLOAT		=> 4;
use constant MYSQL_TYPE_DOUBLE		=> 5;
use constant MYSQL_TYPE_NULL		=> 6;
use constant MYSQL_TYPE_TIMESTAMP	=> 7;
use constant MYSQL_TYPE_LONGLONG	=> 8;
use constant MYSQL_TYPE_INT24		=> 9;
use constant MYSQL_TYPE_DATE		=> 10;
use constant MYSQL_TYPE_TIME		=> 11;
use constant MYSQL_TYPE_DATETIME	=> 12;
use constant MYSQL_TYPE_YEAR		=> 13;
use constant MYSQL_TYPE_NEWDATE		=> 14;
use constant MYSQL_TYPE_VARCHAR		=> 15;
use constant MYSQL_TYPE_BIT		=> 16;
use constant MYSQL_TYPE_NEWDECIMAL	=> 246;
use constant MYSQL_TYPE_ENUM		=> 247;
use constant MYSQL_TYPE_SET		=> 248;
use constant MYSQL_TYPE_TINY_BLOB	=> 249;
use constant MYSQL_TYPE_MEDIUM_BLOB	=> 250;
use constant MYSQL_TYPE_LONG_BLOB	=> 251;
use constant MYSQL_TYPE_BLOB		=> 252;
use constant MYSQL_TYPE_VAR_STRING	=> 253;
use constant MYSQL_TYPE_STRING		=> 254;
use constant MYSQL_TYPE_GEOMETRY	=> 255;

use constant NOT_NULL_FLAG		=> 1;
use constant PRI_KEY_FLAG		=> 2;
use constant UNIQUE_KEY_FLAG		=> 4;
use constant MULTIPLE_KEY_FLAG		=> 8;
use constant BLOB_FLAG			=> 16;
use constant UNSIGNED_FLAG		=> 32;
use constant ZEROFILL_FLAG		=> 64;
use constant BINARY_FLAG		=> 128;
use constant ENUM_FLAG			=> 256;
use constant AUTO_INCREMENT_FLAG	=> 512;
use constant TIMESTAMP_FLAG		=> 1024;
use constant SET_FLAG			=> 2048;
use constant NO_DEFAULT_VALUE_FLAG	=> 4096;
use constant NUM_FLAG			=> 32768;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    return $self;
}

sub _authenticate {
    my ($self, $data) = @_;

    my $database;

    my $ptr = 0;
    my $header_flags = substr($data, $ptr, 4);
    $ptr = $ptr + 4;

    eval {
        my $client_flags = substr($data, $ptr, 4);
        $ptr = $ptr + 4;

        my $max_packet_size = substr($data, $ptr, 4);
        $ptr = $ptr + 4;

        my $charset_number = substr($data, $ptr, 1);
        $self->charset(ord($charset_number));
        $ptr++;

        my $filler1 = substr($data, $ptr, 23);
        $ptr = $ptr + 23;

        my $username_end = index($data, "\0", $ptr);
        my $username = substr($data, $ptr, $username_end - $ptr);
        $ptr = $username_end + 1;

        my $scramble_buff;

        my $scramble_length = ord(substr($data, $ptr, 1));
        $ptr++;

        if ($scramble_length > 0) {
        $self->scramble(substr($data, $ptr, $scramble_length));
        $ptr = $ptr + $scramble_length;
        }

        my $database_end = index( $data, "\0", $ptr);
        if ($database_end != -1 ) {
         $database = substr($data, $ptr, $database_end - $ptr);
        }
#        $database ||= 'NULL';


        $self->database($database);
        $self->username($username);
#        $self->password($database);

    };

#    if ($@) {
#        die $@;
#    }



    if ($database) {


#        print $self->username;
#        print ' ~~ '.$self->database."\n";

        my $module = $self->server_class;

        unless (Class::Inspector->loaded($module)) {
            require Class::Inspector->filename($module);
        }

        if (my $code = $module->can('change_db')) {
            eval {
                $code->($module, $self, $database);
            };

            if ($@) {
                die $@;
            }

            unless ($@) {
                $self->database($database);
            }
        }


        $self->authenticated(1);
        $self->send_ok;
    }
    else {
       $self->send_error('Please choose a database !');
    }
}

sub send_error {
    my ($self, $message, $errno, $sqlstate) = @_;

    $message = 'Unknown MySQL error' if not defined $message;
    $errno = 2000 if not defined $errno;
    $sqlstate = 'HY000' if not defined $sqlstate;

    my $payload = chr(0xff);
    $payload .= pack('v', $errno);
    $payload .= '#';
    $payload .= $sqlstate;
    $payload .= $message."\0";

    $self->write( $payload, 1);
}

sub isa {
    my ($self, $module) = @_;


    if ($module) {
        unless (Class::Inspector->loaded($module)) {
            require Class::Inspector->filename($module);
        }

        pop @ISA if $ISA[$#ISA] ne 'Class::Accessor::Fast';
        push @ISA, $module;

        # register system states
        my @methods = Class::Inspector->methods(
            $module,
            'expanded',
            'public'
        );

        foreach my $method (@{ $methods[0] }) {
            my ($full, $class, $method, undef ) = @{ $method };
            if ($class eq $module) {
                $self->session->_register_state($method, $self);
            }
        }


    }

    return @ISA;
}

sub handle_client_input {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
    my $data = $_[ARG0];

    if (length($data) > 1) {
        $self->packet_count($self->packet_count + 1);
    }
	return undef if length($data) <= 1;

    unless ( $self->authenticated) {
        $self->_authenticate($data);
	}
	else {
        my $header_flags = substr($data, 0, 4);
        $data = substr($data, 4);

        my $event;

        use English;

        print " query = $data in process $PID \n";

#        $event = $self->resolve_sys_query($data);

        unless ($event) {

            eval {
                $event = $self->resolve_query($data);
            };

            if ($@) {
                $event = $self->resolve_sys_query($data);
            }

            if ($self->want_db_name && Class::Inspector->installed($self->server_class."::".$data)) {
                $event = 'select_db';
            }
        };

        POE::Kernel->post(
            $self->session_id,
            $event,
            $data
        );
   }
}

sub resolve_sys_query {
    my ($self, $query) = @_;

    if ($query eq 'select @@version_comment limit 1') {
        return 'select_version';
    }
    elsif ($query =~ /array/) {
        return 'test_myarray';
    }
    elsif ($query eq 'set autocommit=1') {
        return 'return_ok';
    }
    elsif ($query eq 'show databases') {
        return 'show_databases';
    }
    elsif ($query eq 'show tables') {
        return 'show_tables';
    }
    elsif ($query =~ /show table status/i) {
        return 'show_table_status';
    }
    elsif ($query =~ /^use/ or $query =~ /^select database/i) {
        return 'select_db';
    }

    return undef;
}


sub _send_definitions {
    my ($self, $definitions, $skip_envelope) = @_;

	if (not defined $skip_envelope) {
        $self->write($self->_lengthCodedBinary((scalar(@{$definitions}))));
	}

	my $last_send_result;

	foreach my $definition (@{$definitions}) {
        $definition = new_definition(name => $definition) unless ref($definition) eq 'DBIx::MyServer::Definition';
        $self->send_definition($definition);
	};

    if (not defined $skip_envelope) {
        $self->send_definitions_eof();
	}
    else {
		return $last_send_result;
	}
}


sub send_header {
    my ($self, $field_count) = @_;

    $self->write($self->_lengthCodedBinary($field_count));
}

sub send_definitions_eof {
    my ($self) = @_;
    $self->write(chr(0xfe));
}


sub send_definition {
    my ($self, $definition) = @_;

	my (
		$field_catalog, $field_db, $field_table,
		$field_org_table, $field_name, $field_org_name,
		$field_length, $field_type, $field_flags,
		$field_decimals, $field_default
	) = (
		$definition->[FIELD_CATALOG], $definition->[FIELD_DB],
		$definition->[FIELD_TABLE], $definition->[FIELD_ORG_TABLE],
		$definition->[FIELD_NAME], $definition->[FIELD_ORG_NAME],
		$definition->[FIELD_LENGTH], $definition->[FIELD_TYPE],
		$definition->[FIELD_FLAGS], $definition->[FIELD_DECIMALS],
		$definition->[FIELD_DEFAULT]
	);

	my $payload = join('', map { $self->_lengthCodedString($_) } (
		$field_catalog, $field_db, $field_table,
		$field_org_table, $field_name, $field_org_name
	));

	$payload .= chr(0x0c);	# Filler
	$payload .= pack('v', 11);		# US ASCII
	$payload .= pack('V', $field_length);
	$payload .= chr($field_type);
	$payload .= defined $field_flags ? pack('v', $field_flags) : pack('v', 0);
	$payload .= defined $field_decimals ? chr($field_decimals) : pack('v','0');
	$payload .= pack('v', 0);		# Filler
	$payload .= $self->_lengthCodedString($field_default);

   $self->write($payload);
}


sub send_eof {
    my ($self, $warning_count, $server_status) = @_;

	my $payload;

	$warning_count = 0 if not defined $warning_count;
	$server_status = SERVER_STATUS_AUTOCOMMIT if not defined $server_status;

	$payload .= chr(0xfe);
	$payload .= pack('v', $warning_count);
	$payload .= pack('v', $server_status);

   $self->write($payload, 1);
}

sub send_ok {
    my ($self, $message, $affected_rows, $insert_id, $printing_count) = @_;

    my $data;

    $affected_rows = 0 if not defined $affected_rows;
    $printing_count = 0 if not defined $printing_count;

    $data .= "\0";
    $data .= $self->_lengthCodedBinary($affected_rows);
    $data .= $self->_lengthCodedBinary($insert_id);
    $data .= pack('v', SERVER_STATUS_AUTOCOMMIT);
    $data .= pack('v', $printing_count);
    $data .= $self->_lengthCodedString($message);

    $self->write( $data, 1);
}

sub write {
    my ($self, $message, $reinit) = @_;

    my $header;
    $header .= substr(pack('V',length($message)),0,3);
    $header .= chr($self->packet_count % 256);

    if ($reinit) {
        $self->packet_count(0);
    }
    else {
        $self->packet_count($self->packet_count + 1);
    }

    $self->wheel->put($header.$message);
}


sub _lengthCodedString {
	my ($self, $string) = @_;
	return chr(0) if (not defined $string);
	return chr(253).substr(pack('V',length($string)),0,3).$string;
}

sub _lengthCodedBinary {
	my ($self, $number) = @_;
	if (not defined $number) {
		return chr(251);
	}
    elsif ($number < 251) {
		return chr($number);
	}
    elsif ($number < 0x10000) {
		return chr(252).pack('v', $number);
	}
    elsif ($number < 0x1000000) {
		return chr(253).substr(pack('V', $number), 0, 3);
	}
    else {
		return chr(254).pack('V', $number >> 32).pack('V', $number & 0xffffffff);
	}
}

sub handle_client_error {
    my ($self) = shift;
    my ($kernel, $session, $heap ) = @_[ KERNEL, SESSION, HEAP];
    my ($operation, $errnum, $errstr, $wheel_id) = @_[ARG0..ARG3];
    print "Wheel $wheel_id generated $operation error $errnum: $errstr\n";
}

sub handle_client_connect {
    my ($self) = shift;

    $self->banner("POE::Component::DBIx::MyServer ".$VERSION."\0");
    $self->salt(join('',map { chr(int(rand(255))) } (1..20)));
    $self->charset(0x21);
    $self->tid($$);
    $self->packet_count(0);

    my $payload = chr(10);
    $payload .= $self->banner;
    $payload .= pack('V', $self->tid);
    $payload .= substr($self->salt,0,8)."\0";
#    $payload .= pack('v', CLIENT_LONG_PASSWORD | CLIENT_CONNECT_WITH_DB | CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION);
    $payload .= pack('v', CLIENT_CONNECT_WITH_DB | CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION);
    $payload .= $self->charset;
    $payload .= pack('v', SERVER_STATUS_AUTOCOMMIT);
    $payload .= "\0" x 13;
    $payload .= substr($self->salt,8)."\0";

    $self->write($payload);
}

sub handle_client_disconnect {
   my ( $kernel, $session, $heap ) = @_[ KERNEL, SESSION, HEAP];

   print "handle_client_disconnect"."\n" if DEBUG;
}

sub _send_rows {
    my ($self, $rows) = @_;
    $self->send_eof if not defined $rows;

	foreach my $row (@$rows) {

        my $small_data;
        if (ref($row) eq 'ARRAY') {
            foreach (@$row) {
                if (not defined $_) {
                    $small_data .= chr(251);
                }
                else {
                    $small_data .= $self->_lengthCodedString($_);
                }
            }
        }
        elsif (ref($row) eq 'HASH') {
            foreach (values %{ $row }) {
                if (not defined $_) {
                    $small_data .= chr(251);
                }
                else {
                    $small_data .= $self->_lengthCodedString($_);
                }
            }
        }

        if (defined $small_data) {
            my $header;
            $header .= substr(pack('V',length($small_data)),0,3);
            $header .= chr($self->packet_count % 256);
            $self->packet_count($self->packet_count + 1);

            $self->wheel->put($header.$small_data);
        }
	}

    $self->send_eof;
}

sub send_results {
    my ($self, $definitions, $data) = @_;
    $self->_send_definitions($definitions);
    $self->_send_rows($data);
}

sub select_version {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
    my $data = $_[ARG0];

    $self->send_results(['version'], [[ 'on perl '.$] ]]);
}

sub return_empty_set {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];

    $self->send_results(['empty_set'], [['']]);
}

sub show_table_status {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
    print "";
    $self->send_results(['Name', 'Engine', 'Version', 'Row_format', 'Rows', 'Avg_row_length', 'Data_length', 'Max_data_length', 'Index_length', 'Data_free', 'Auto_increment', 'Create_time', 'Update_time', 'Check_time', 'Collation', 'Checksum', 'Create_options', 'Comment'], [['Name', 'Engine', 'Version', 'Row_format', 'Rows', 'Avg_row_length', 'Data_length', 'Max_data_length', 'Index_length', 'Data_free', 'Auto_increment', 'Create_time', 'Update_time', 'Check_time', 'Collation', 'Checksum', 'Create_options', 'Comment']]);
}

sub return_ok {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
    my $data = $_[ARG0];

    $self->send_ok;
}

sub test_myarray {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
    my $data = $_[ARG0];

    print 'test ~ session ID = '.$session->ID."\n";

    print "version_comment !! \n";

    my @ss;

    for (0..99) {
        $ss[$_] = ();
        push @{ $ss[$_] }, 'index '.$_;
    }

    $self->send_results([new_definition( name => 'field' )], \@ss);

    print "da DB was sent ... \n";
}

sub test_tables {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
   my $data = $_[ARG0];

    print 'test ~ session ID = '.$session->ID."\n";

   	  print "version_comment !! \n";

      $self->send_results([new_definition( name => 'Tables_in_testdb' )],
            [['mytable_'.$session->ID,'mytable_'.$session->ID,'mytable_'.$session->ID]]);

      print "da DB was sent ... \n";


}


sub show_tables {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
    my $data = $_[ARG0];
    # so mysql client don't complain about stuff he
    # doesnt know from each table ..
    $self->send_results(['Tables_in_'.$self->database],[]);
}

sub select_db {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
    my $data = $_[ARG0];

    # module load and shit ...
    my $module = $self->server_class;

    if ($data =~ /\(\)/) {
        $self->want_db_name(1);
        $self->send_results(['database()'], [[$self->database]]);
    }
    else {

        $self->want_db_name(0);

        unless (Class::Inspector->loaded($module)) {
            require Class::Inspector->filename($module);
        }

        if (my $code = $module->can('change_db')) {
            eval {
                $code->($module, $self, $data);
            };

            unless ($@) {
                $self->database($data);
#                $self->send_results(['database()'], [[$data]]);
                $self->send_ok;
            }
            else {
                $self->send_error($@);
            }
        }
    }
}


sub show_databases {
    my ( $kernel, $session, $heap, $self ) = @_[ KERNEL, SESSION, HEAP, OBJECT];
    my $data = $_[ARG0];
    my @results;

    my $server_class = $self->server_class;
    my @found = useall $self->server_class;

    foreach my $database_class (@found) {
        $database_class =~ s/$server_class\:\://g;
        push @results, [$database_class];
    }

    $self->send_results(['Database'], \@results);
}

sub new_definition {
	my %params = @_;

	my $definition = bless([], 'DBIx::MyServer::Definition');
	$definition->[FIELD_CATALOG] = $params{catalog};
	$definition->[FIELD_DB] = $params{db} ? $params{db} : $params{database};
	$definition->[FIELD_TABLE] = $params{table};
	$definition->[FIELD_ORG_TABLE] = $params{org_table};
	$definition->[FIELD_NAME] = $params{name};
	$definition->[FIELD_ORG_NAME] = $params{org_name};
	$definition->[FIELD_LENGTH] = defined $params{length} ? $params{length} : 0;
	$definition->[FIELD_TYPE] = defined $params{type} ? $params{type} : MYSQL_TYPE_STRING;
	$definition->[FIELD_FLAGS] = defined $params{flags} ? $params{flags} : 0;
	$definition->[FIELD_DECIMALS] = $params{decimals};
	$definition->[FIELD_DEFAULT] = $params{default};
	return $definition;
}





=head1 NAME

POE::Component::DBIx::MyServer::Client - A client connection to our server

=head1 DESCRIPTION

This class is instantiated each time a client connects to our PoCo::DBIx::MyServer.

It provides a system resolver for a few base mysql queries (select @version_comment ..).

It also provides the methods with which you can send data to the client, send ok
and send errors.

=head1 SYNOPSYS

Then you can create various classes (that subclass the PoCo::DBIx::MyServer::Client
class) that will behave as databases in your mysql server.

    package MyServer::HelloWorld;

    use POE;

    sub resolve_query {
        my ($self, $query) = @_;
        return 'hello_world_event';
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

=head1 METHODS

=head2 send_results

This actually send results and columns name to the client.

=head2 send_ok

This send an ok to the client.

=head2 send_error

This returns an error to the client.

=head1 AUTHORS

Eriam Schaffter, C<eriam@cpan.org> and original work done by Philip Stoev in the DBIx::MyServer module.

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut



1;
