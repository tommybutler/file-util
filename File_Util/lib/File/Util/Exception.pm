use 5.006;
use strict;
use warnings;

package File::Util::Exception;

use lib 'lib';

use File::Util::Definitions qw( :all );
use File::Util::Interface::Classic qw( _remove_opts );
use File::Util::Exception::Diagnostic qw( :all );

use vars qw(
   @ISA    $AUTHORITY
   @EXPORT_OK  %EXPORT_TAGS
);

use Exporter;

$AUTHORITY  = 'cpan:TOMMY';
@ISA        = qw( Exporter );
@EXPORT_OK  = qw( _throw );

%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );


# --------------------------------------------------------
# File::Util::_throw
# --------------------------------------------------------
sub _throw {
   my $this = shift @_;
   my $opts = _remove_opts( \@_ );
   my %fatal_rules = ();

   # fatalality-handling rules passed to the failing caller trump the
   # rules set up in the attributes of the object; the mechanism below
   # also allows for the implicit handling of fatals_are_fatal => 1
   map { $fatal_rules{ $_ } = $_ }
   grep /^fatals/o, values %$opts;

   unless ( scalar keys %fatal_rules ) {
      map { $fatal_rules{ $_ } = $_ }
      grep /^fatals/o, keys %{ $this->{opts} }
   }

   return 0 if $fatal_rules{'fatals_as_status'};

   $this->{expt} ||= { };

   unless ( UNIVERSAL::isa( $this->{expt}, 'Exception::Handler' ) ) {

      require Exception::Handler;

      $this->{expt} = Exception::Handler->new();
   }

   my $error = ''; my $in = { };

   $in->{_pak} = __PACKAGE__;

   if ( scalar @_ == 1 ) {

      $error = $_[0] ? 'plain error' : 'empty error';

      $in->{error} = $_[0] || 'error undefined';

      goto PLAIN_ERRORS;
   }
   else {

      $error = shift @_ || 'empty error';

      if ( $error eq 'plain error' ) {

         $in->{error} = shift @_;

         $in->{error} = 'error undefined'
            unless defined $in->{error} && length $in->{error};

         goto PLAIN_ERRORS;
      }
   }

   $in = shift @_ || { };

   $in->{_pak} = __PACKAGE__;

   ## no critic
   map { $_ = defined $_ ? $_ : 'undefined value' } keys %$in;
   ## use critic

   PLAIN_ERRORS:

   my $bad_news =
      CORE::eval
         (
            q{<<__ERRORBLOCK__}
            . &NL . &_errors( $error )
            . &NL . q{__ERRORBLOCK__}
         );

## for debugging only
#   if ($@) { return $this->{expt}->trace($@) }

   if ( $fatal_rules{fatals_as_warning} ) {

      warn $this->{expt}->trace( $@ || $bad_news ) and return;
   }
   elsif ( $fatal_rules{fatals_as_errmsg} || $opts->{return} ) {

      return $this->{expt}->trace( $@ || $bad_news );
   }

   foreach ( keys %$in ) {

      next if $_ eq 'opts';

      $bad_news .= qq[ARG   $_ = $in->{$_}] . $NL;
   }

   if ( $in->{opts} ) {

      foreach ( keys %{ $$in{opts} } ) {

         $_ = defined $_ ? $_  : 'empty value';

         $bad_news .= qq[OPT   $_] . $NL;
      }
   }

   warn $this->{expt}->trace( $@ || $bad_news ) if $opts->{warn_also};

   $this->{expt}->fail( $@ || $bad_news );

   return '';
}

=pod

=head1 NAME

File::Util::Exception

=head1 DESCRIPTION

Base class for all File::Util::Exception subclasses.  It's primarily
responsible for error handling within File::Util, but hands certain
work off to its subclasses, depending on how File::Util was use()'d.

Don't use this module by itself.  It is for internal use only.

=cut

# --------------------------------------------------------
# File::Util::Exception::DESTROY()
# --------------------------------------------------------
sub DESTROY { }

1;
