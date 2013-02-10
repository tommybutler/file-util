
use strict;
use warnings;

use Test::More;
use File::Temp qw( tempdir );

use lib './lib';

use File::Util qw( SL NL existent );

# ----------------------------------------------------------------------
# determine if we can run these fatal tests
# ----------------------------------------------------------------------
BEGIN {

   if ( $^O !~ /bsd|linux|cygwin/i )
   {
      plan skip_all => 'this OS doesn\'t fail reliably - chmod() issues';
   }
   # the tests in this file have a higher probability of failing in the
   # wild, and so are reserved for the author/maintainers as release tests.
   # these tests also won't reliably run on platforms that can't run or
   # can't respect chmod()... e.g.- windows (and even cygwin to some extent)
   elsif ( $ENV{RELEASE_TESTING} || $ENV{AUTHOR_TESTING} || $ENV{AUTHOR_TESTS} )
   {
      {
         local $@;

         CORE::eval 'use Test::Fatal';

         if ( $@ )
         {
            plan skip_all => 'Need Test::Fatal to run these tests';
         }
         else
         {
            require Test::Fatal;

            Test::Fatal->import( qw( exception dies_ok lives_ok ) );

            plan tests => 29;

            CORE::eval <<'__TEST_NOWARNINGS__';
use Test::NoWarnings qw( :early );
__TEST_NOWARNINGS__
         }
      }
   }
   else
   {
      plan skip_all => 'these tests are for testing by the author';
   }
}

my $ftl     = File::Util->new();
my $tempdir = tempdir( CLEANUP => 1 );
my $exception;

# ----------------------------------------------------------------------
# set ourselves up for failure
# ----------------------------------------------------------------------

# list of methods that will throw a special exception unless they get
# the input that they require
my @methods_that_need_input = qw(
   list_dir       load_file      write_file     touch
   load_dir       make_dir       open_handle
);

# make an inaccessible file
my $noaccess_file = make_inaccessible_file( 'noaccess.txt' );

# make a directory, inaccessible
my $noaccess_dir = make_inaccessible_dir( 'noaccess/' );

# make a somewhat-deep temp dir structure
$ftl->make_dir( $tempdir . SL . 'a' . SL . 'b' . SL . 'c' );

# ----------------------------------------------------------------------
# let the fail begin
# ----------------------------------------------------------------------

# the first of our tests are  several simple failure scenarios wherein no
# input is sent to a given method that requires it.
for my $method ( @methods_that_need_input )
{
   # send no input to $method
   $exception = exception { $ftl->$method() };

   like $exception,
        qr/(?m)^Call to \( $method\(\) \) failed:/,
        sprintf 'send no input to %s()', $method;
}

# try to read-open a file that doesn't exist
$exception = exception { $ftl->load_file( get_nonexistent_file() ) };

like $exception,
     qr/(?m)^File inaccessible or does not exist:/,
     'attempt to read non-existant file';

# try to set a bad flock policy
$exception = exception { $ftl->flock_rules( 'dummy' ) };

like $exception,
     qr/(?m)^Invalid file locking policy/,
     'make a call to flock_rules() with improper input';

# try to read an inaccessible file
$exception = exception { $ftl->load_file( $noaccess_file ) };

like $exception,
     qr/(?m)^Permissions conflict\.  Can't read:/,
     'attempt to read an inaccessible file';

# try to write to an inaccessible file
$exception = exception { $ftl->write_file( $noaccess_file => 'dummycontent' ) };

like $exception,
     qr/(?m)^Permissions conflict\.  Can't write to:/,
     'attempt to write to an inaccessible file';

# try to access a file in an inaccessible directory
$exception = exception { $ftl->load_file( $noaccess_dir . SL . 'dummyfile' ) };

like $exception,
     qr/(?m)^File inaccessible|^Permissions conflict/,
     'attempt to read a file in a restricted directory';

# try to create a file in the inaccessible directory
$exception = exception
{
   $ftl->write_file( $noaccess_dir . SL . 'dummyfile' => 'dummycontent' )
};

like $exception,
     qr/(?m)^Permissions conflict.  Can't (?:create|write)/, # cygwin differs
     'attempt to create a file in a restricted directory';

# try to open a directory as a file for reading
$exception = exception { $ftl->load_file( '.' ) };

like $exception,
     qr/(?m)^Can't call open\(\) on a directory:/,
     'attempt to do file open() on a directory (read)';

# try to open a directory as a file for writing
$exception = exception { $ftl->write_file( '.' => 'dummycontent' ) };

like $exception,
     qr/(?m)^File already exists as directory:/,
     'attempt to do file open() on a directory (write)';

# try to open a file with a bad "mode" argument
$exception = exception
{
   $ftl->write_file(
      {
         filename => 'dummyfile',
         content  => 'dummycontent',
         mode     => 'chuck norris',   # << invalid
         onfail   => 'roundhouse',     # << invalid
      }
   )
};

like $exception,
     qr/(?m)^Illegal mode specified for file open:/,
     'provide illegal open "mode" to write_file()';

# try to SYSopen a file with a bad "mode" argument
$exception = exception
{
   $ftl->open_handle
   (
      {
         use_sysopen => 1,
         filename    => 'dummyfile',
         mode        => 'stealth monkey', # << invalid
      }
   )
};

like $exception,
     qr/(?m)^Illegal mode specified for sysopen:/,
     'provide illegal SYSopen "mode" to write_file()';

# try to opendir on an inaccessible directory
$exception = exception { $ftl->list_dir( $noaccess_dir ) };

like $exception,
     qr/(?m)^Can't opendir on directory:/,
     'attempt list_dir() on an inaccessible directory';

# try to makedir in an inaccessible directory
$exception = exception
{ $ftl->make_dir( $noaccess_dir . SL . 'snowballs_chance/' ) };

like $exception,
     qr/(?m)^Permissions conflict\.  Can't create directory:/,
     'attempt make_dir() in an inaccessible directory';

# try to makedir for an existent directory
$exception = exception { $ftl->make_dir( '.' ) };

like $exception,
     qr/(?m)^make_dir target already exists:/,
     'attempt make_dir() for a directory that already esists';

# try to makedir on a file
$exception = exception { $ftl->make_dir( __FILE__ ) };

like $exception,
     qr/(?m)^Can't make directory; already exists as a file/,
     'attempt make_dir() on a file';

# try to list_dir() on a file
$exception = exception { $ftl->list_dir( __FILE__ ) };

like $exception,
     qr/(?m)^Can't opendir\(\) on non-directory:/,
     'attempt to list_dir() on a file';

# try to read more data from a file than the enforced readlimit amount
# ...we set the readlimit purposely low to induce the error
$exception = exception { $ftl->load_file( __FILE__, { readlimit => 0 } ) };

like $exception,
     qr/(?m)^Stopped reading:/,
     'attempt to read a file that\'s bigger than the set readlimit';

# send bad input to maxdives()
$exception = exception { $ftl->max_dives( 'cheezburger' ) };

like $exception,
     qr/(?m)^Bad input provided to max_dives/,
     'make a call to max_dives() with improper input';

# send bad input to readlimit()
$exception = exception { $ftl->readlimit( 'woof!' ) };

like $exception,
     qr/(?m)^Bad input provided to readlimit/,
     'make a call to readlimit() with improper input';

# intentionally exceed max_dives
$exception = exception
{
   $ftl->list_dir( $tempdir => { recurse => 1, max_dives => 1 } )
};

like $exception,
     qr/(?m)^Recursion limit exceeded/,
     'attempt to list_dir recursively past max_dives limit';

# send bad input to readlimit()
$exception = exception
{
   $ftl->write_file( $tempdir . SL . 'foo\\\\bar' => 'dummycontent' )
};

like $exception,
     qr/(?m)^String contains illegal characters:/,
     'attempt to create a file with filename containing illegal characters';

# call write_file() with an invalid file handle
$exception = exception
{
   $ftl->load_file( file_handle => 'not a file handle at all' )
};

like $exception,
     qr/a true file handle reference/,
     'call write_file with a file handle that is invalid (not a real FH ref)';



# ----------------------------------------------------------------------
# clean up restricted-access files/dirs, and exit
# ----------------------------------------------------------------------

remove_inaccessible_file( $noaccess_file );
remove_inaccessible_dir( $noaccess_dir );

exit;


# ----------------------------------------------------------------------
# supporting subroutines
# ----------------------------------------------------------------------

sub make_inaccessible_file
{
   my $filename = $ftl->strip_path( shift @_ );

   $filename = $tempdir . SL . $filename;

   $ftl->touch( $filename );

   chmod oct 0, $filename or die $!;

   return $filename;
}

sub remove_inaccessible_file
{
   my $filename = $ftl->strip_path( shift @_ );

   $filename = $tempdir . SL . $filename;

   chmod oct 777, $filename or die $!;

   unlink $filename or die $!;
}

sub make_inaccessible_dir
{
   my $dirname = $ftl->strip_path( shift @_ );

   $dirname = $tempdir . SL . $dirname;

   $ftl->make_dir( $dirname );

   $ftl->touch( $dirname . SL . 'dummyfile' );

   chmod oct 0, $dirname . SL . 'dummyfile' or die $!;
   chmod oct 0, $dirname or die $!;

   return $dirname;
}

sub remove_inaccessible_dir
{
   my $dirname = $ftl->strip_path( shift @_ );

   $dirname = $tempdir . SL . $dirname;

   chmod oct 777, $dirname or die $!;
   chmod oct 777, $dirname . SL . 'dummyfile' or die $!;

   unlink $dirname . SL . 'dummyfile' or die $!;

   rmdir $dirname or die $!;
}

sub get_nonexistent_file
{
   my $file = ( rand 100 ) . time . $$;

   while ( -e $file )
   {
      $file = get_nonexistent_file();
   }

   return $file;
}

