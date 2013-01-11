use 5.006;
use strict;
use warnings;

package File::Util::Interface::Classic;

use Scalar::Util qw( blessed );

use lib 'lib';

use File::Util::Definitions qw( :all );

use vars qw(
   @ISA    $AUTHORITY
   @EXPORT_OK  %EXPORT_TAGS
);

use Exporter;

$AUTHORITY  = 'cpan:TOMMY';
@ISA        = qw( Exporter );
@EXPORT_OK  = qw(
   _myargs
   _remove_opts
   _names_values
);

%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );


# --------------------------------------------------------
# File::Util::_myargs()
# --------------------------------------------------------
sub _myargs {

   shift @_ if blessed $_[0];

   return wantarray ? @_ : $_[0]
}


# --------------------------------------------------------
# File::Util::_remove_opts()
# --------------------------------------------------------
sub _remove_opts {

   my $args = _myargs( @_ );

   return unless UNIVERSAL::isa( $args, 'ARRAY' );

   my @triage = @$args; @$args = ();
   my $opts   = {};

   while ( @triage ) {

      my $arg = shift @triage;

      # if an argument is '', 0, or undef, it's obviously not an --option ...
      push @$args, $arg and next unless $arg; # ...so give it back to the @$args

      # hmmm.  looks like an "--option" argument, if:
      if ( $arg =~ /^--/o ) {

         # it's either a bare "--option", or it's an "--option=value" pair
         my ( $opt, $value ) = split /=/o, $arg;

         $opts->{ $opt } = defined $value ? $value : $arg;
         $opts->{ substr $opt, 2 } = defined $value ? $value : substr $opt, 2;
      }
      else {

         # but if it's not an "--option" type arg, give it back to the @$args
         push @$args, $arg;
      }
   }

   return $opts;
}


# --------------------------------------------------------
# File::Util::_names_values()
# --------------------------------------------------------
sub _names_values {

   my @pairs   = _myargs( @_ );
   my $nvpairs = {};
   my $i       = 0;

   while ( my ( $name, $val ) = splice @pairs, 0, 2 ) {

      $nvpairs->{ $name } = $val;
   }

   return $nvpairs;
}

1;
