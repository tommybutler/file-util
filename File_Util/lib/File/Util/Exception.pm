use strict;
use warnings;

package File::Util::Exception;

use lib 'lib';

use File::Util::Definitions qw( :all );
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
   my @in   = @_;
   my $opts = $this->_remove_opts( \@_ );
   my %fatal_rules = ();

   # fatalality-handling rules passed to the failing caller trump the
   # rules set up in the attributes of the object; the mechanism below
   # also allows for the implicit handling of fatals_are_fatal => 1
   map { $fatal_rules{ $_ } = $_ }
   grep /^fatals/o, keys %$opts;

   unless ( scalar keys %fatal_rules ) {
      map { $fatal_rules{ $_ } = $_ }
      grep /^fatals/o, keys %{ $this->{opts} }
   }

   return 0 if $fatal_rules{fatals_as_status};

   $this->{expt} ||= { };

   unless ( UNIVERSAL::isa( $this->{expt}, 'Exception::Handler' ) ) {

      require Exception::Handler;

      $this->{expt} = Exception::Handler->new();
   }

   my $error = '';

   if ( scalar @in == 1 && !scalar keys %$opts ) {

      $opts->{_pak} = __PACKAGE__;

      $error = $in[0] ? 'plain error' : 'empty error';

      $opts->{error} = $in[0] || 'error undefined';

      goto PLAIN_ERRORS;
   }
   else {

      $opts->{_pak} = __PACKAGE__;

      $error = shift @_ || 'empty error';

      if ( $error eq 'plain error' ) {

         $opts->{error} = shift @_;

         $opts->{error} = 'error undefined'
            unless defined $opts->{error} && length $opts->{error};

         goto PLAIN_ERRORS;
      }
   }

   ## no critic
   map { $_ = defined $_ ? $_ : 'undefined value' } keys %$opts;
   ## use critic

   PLAIN_ERRORS:

   my $bad_news =
      CORE::eval
         (
            q{<<__ERRORBLOCK__}
            . &NL . &_errors( $error )
            . &NL . q{__ERRORBLOCK__}
         );

   if ( $fatal_rules{fatals_as_warning} ) {

      warn $this->{expt}->trace( $@ || $bad_news ) and return;
   }
   elsif ( $fatal_rules{fatals_as_errmsg} || $opts->{return} ) {

      return $this->{expt}->trace( $@ || $bad_news );
   }

   foreach ( keys %$opts ) {

      next if $_ eq 'opts';

      $bad_news .= qq[ARG   $_ = $opts->{$_}] . $NL;
   }

   if ( $opts->{opts} ) {

      foreach ( keys %{ $$opts{opts} } ) {

         $_ = defined $_ ? $_  : 'empty value';

         $bad_news .= qq[OPT   $_] . $NL;
      }
   }

   warn $this->{expt}->trace( $@ || $bad_news ) if $opts->{warn_also};

   $this->{expt}->fail( $@ || $bad_news );

   return '';
}


# --------------------------------------------------------
# File::Util::Exception::DESTROY()
# --------------------------------------------------------
sub DESTROY { }

1;


__END__

=pod

=head1 NAME

File::Util::Exception

=head1 DESCRIPTION

Base class for all File::Util::Exception subclasses.  It's primarily
responsible for error handling within File::Util, but hands certain
work off to its subclasses, depending on how File::Util was use()'d.

Users, don't use this module by itself.  It is for internal use only.

=cut

