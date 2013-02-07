
use strict;
use warnings;

use Test::More;

BEGIN {

   # the tests in this file have a higher probability of failing in the
   # wild, and so are reserved for the author/maintainers as release tests
   if ( $ENV{RELEASE_TESTING} || $ENV{AUTHOR_TESTING} || $ENV{AUTHOR_TESTS} )
   {
      {
         local $@;

         CORE::eval 'use Test::Fatal';

         if ( $@ )
         {
            plan skip_all => 'Need Test::Fatal to run these tests';
         }
         else {

            require Test::Fatal;

            Test::Fatal->import( qw( exception dies_ok lives_ok ) );

            plan tests => 3;

            CORE::eval <<'__TEST_NOWARNINGS__';
use Test::NoWarnings qw( :early );
__TEST_NOWARNINGS__

            diag 'All of these tests should die in order to pass';
         }
      }
   }
   else
   {
      plan skip_all => 'these tests are for testing by the author';
   }
}

use lib './lib';

use File::Util qw( SL NL existent );

my $ftl = File::Util->new();
my $exception;

$exception = exception { $ftl->load_file( get_nonexistent_file() ) };

like $exception,
     qr/(?m)^File inaccessible or does not exist:/,
     'file open to non-existant file';

$exception = exception { $ftl->flock_rules( 'dummy' ) };

like $exception,
     qr/(?m)^Invalid file locking policy/,
     'bad call to flock_rules()';




exit;


sub get_nonexistent_file
{
   my $file = ( rand 100 ) . time . $$;

   while ( -e $file )
   {
      $file = get_nonexistent_file();
   }

   return $file;
}

