use strict;
use warnings;

use lib 'lib';

package File::Util::ProxyLog;

use Time::HiRes;
use Data::Dumper;
   $Data::Dumper::Purity   = 1;
   $Data::Dumper::Indent   = 2;
   $Data::Dumper::Terse    = 1;
   $Data::Dumper::Sortkeys = 1;

our $LOGFILE;
our $LOGFH;

sub new
{
   my ( $class, $proxied, $logfile ) = @_;

   $LOGFILE = $logfile || die 'Need log file for call proxy logging';

   $LOGFH   = $proxied->open_handle( $logfile => { mode => 'append' } );

   bless \$proxied, $class;
}

sub AUTOLOAD
{
   my ( $name ) = our $AUTOLOAD =~ /.*::(\w+)$/;

   my $self = shift @_;
   my $time = time;
   my $dump = qq(@{[ Dumper \@_ ]});

   print $LOGFH <<__CALL__;
--------------------------------------------------------------------------------
$time $name called with these args:
$time   @{[ join "\n$time   ", split /\n/, $dump ]}
__CALL__

   return $$self->$name( @_ );
}

sub DESTROY { if ( $LOGFH ) { close $LOGFH or die $! } return }

1;

__END__

=pod

=head1 NAME

File::Util::ProxyLog - a call logging proxy class for File::Util

=head1 DESCRIPTION

This module serves as an aid in debugging File::Util method calls, logging
each call to a file of your choosing.  Just `tail -f` the log file and run
your program.

B<File::Util does not depend on or use this module.  It is stand-alone code.>

This module is mainly a tool for the developers of File::Util to use in their
testing, and is designed for that purpose.  Perl programmers can use it if
they like, but it should not be considered an official part of the File::Util
distribution for end-users, as its interface could change at any time to suit
the needs of its maintainers.  This module is therefore primarily "for internal
use only."

=head1 SYNOPSIS

   use File::Util qw( SL );
   use File::Util::ProxyLog;

   my $fto = File::Util->new( { fatals_as_status => 1 } );

   my $log = '/tmp/File-Util.log';

   my $ftl = File::Util::ProxyLog->new( $fto, $log );

   # now use $ftl like you would use any File::Util object, and watch the log...

   print $ftl->list_dir( '/some/directory' => { recurse => 1 } );

=head1 METHODS

=over

=item new

   my $ftl = File::Util::ProxyLog->new( $file_util_object, $log_file_name );

=back

=cut
