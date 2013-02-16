use strict;
use warnings;

use lib 'lib';

package File::Util::Exception;

# ABSTRACT: Base exception class for File::Util

use File::Util::Definitions qw( :all );

use vars qw(
   @ISA    $AUTHORITY
   @EXPORT_OK  %EXPORT_TAGS
);

use Exporter;

$AUTHORITY   = 'cpan:TOMMY';
@ISA         = qw( Exporter );
@EXPORT_OK   = qw( _throw );
%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );


# --------------------------------------------------------
# File::Util::Exception::_throw
# --------------------------------------------------------
sub _throw {

   my @in = @_;
   my ( $this, $error_class, $error ) = splice @_, 0 , 3;
   my $opts = $this->_remove_opts( \@_ );
   my %fatal_rules = ();

   # here we handle support for the legacy error handling policy syntax,
   # such as things like "fatals_as_status => 1"
   #
   # ...and we also handle support for the newer, more pretty error
   # handling policy syntax using "onfail" keywords/subrefs

   $opts->{onfail} ||=
      $opts->{opts} && ref $opts->{opts} eq 'HASH'
         ? $opts->{opts}->{onfail}
         : '';

   $opts->{onfail} ||= $this->{opts}->{onfail};

   $opts->{onfail} ||= 'die';

   # fatalality-handling rules passed to the failing caller trump the
   # rules set up in the attributes of the object; the mechanism below
   # also allows for the implicit handling of fatals_are_fatal => 1
   map { $fatal_rules{ $_ } = $_ }
   grep /^fatals/o, keys %$opts;

   map { $fatal_rules{ $_ } = $_ }
   grep /^fatals/o, keys %{ $opts->{opts} }
      if $opts->{opts} && ref $opts->{opts} eq 'HASH';

   unless ( scalar keys %fatal_rules ) {
      map { $fatal_rules{ $_ } = $_ }
      grep /^fatals/o, keys %{ $this->{opts} }
   }

   return 0 if $fatal_rules{fatals_as_status} || $opts->{onfail} eq 'zero';

   return if $opts->{onfail} eq 'undefined';

   $this->{expt} ||= { };

   unless ( UNIVERSAL::isa( $this->{expt}, 'Exception::Handler' ) ) {

      require Exception::Handler;

      $this->{expt} = Exception::Handler->new();
   }

   my $is_plain;

   if ( !scalar keys %$opts ) {

      $opts->{_pak} = 'File::Util';

      $opts->{error} = $error;

      $error = $error ? 'plain error' : 'empty error';

      $is_plain++;
   }
   else {

      $opts->{_pak} = 'File::Util';

      $error ||= 'empty error';

      if ( $error eq 'plain error' ) {

         $opts->{error} = shift @_;

         $is_plain++;
      }
   }

   ## no critic
   map { $_ = defined $_ ? $_ : 'undefined value' }
   keys %$opts
   unless $is_plain;
   ## use critic

   my $bad_news = CORE::eval # tokenizing via stringy eval (is NOT evil)
   (
      '<<__ERRBLOCK__' . NL .
         $error_class->_errors( $error ) . NL .
      '__ERRBLOCK__'
   );

   if (
      $opts->{onfail} eq 'warn' ||
      $fatal_rules{fatals_as_warning}
   ) {
      warn $this->{expt}->trace( $@ || $bad_news ) and return;
   }
   elsif (
      $opts->{onfail} eq 'message'   ||
      $fatal_rules{fatals_as_errmsg} ||
      $opts->{return}
   ) {
      return $this->{expt}->trace( $@ || $bad_news );
   }

   warn $this->{expt}->trace( $@ || $bad_news ) if $opts->{warn_also};

   die $this->{expt}->trace( $@ || $bad_news )
      unless ref $opts->{onfail} eq 'CODE';

   # the substr trick below just gets rid of the informational header on
   # the stack trace, automatically placed there by Exception::Handler

   @_ = ( $bad_news, substr $this->{expt}->trace('_'), 3 );

   goto $opts->{onfail};
}


# --------------------------------------------------------
# File::Util::Exception::DESTROY()
# --------------------------------------------------------
sub DESTROY { }


1;


__END__

=pod

=head1 NAME

File::Util::Exception - Base exception class for File::Util

=head1 DESCRIPTION

Base class for all File::Util::Exception subclasses.  It's primarily
responsible for error handling within File::Util, but hands certain
work off to its subclasses, depending on how File::Util was use()'d.

Users, don't use this module by itself.  It is for internal use only.

=cut

