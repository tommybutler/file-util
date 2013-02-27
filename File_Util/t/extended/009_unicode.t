
use strict;
use warnings;

use Test::More;
use File::Temp qw( tempdir );

use lib './lib';

use File::Util qw( SL NL existent );


BEGIN # determine if we can run these unicode tests, or skip_all
{
   {
      local $@;

      my $have_uu = eval { require 5.008001; use utf8; };

      sub have_unicode { $have_uu }
   }

   unless ( have_unicode() )
   {
      plan skip_all => 'your Perl does not appear to support unicode';
   }
   else
   {
      plan tests => 8;

      CORE::eval <<'__TEST_NOWARNINGS__';
use Test::NoWarnings;
__TEST_NOWARNINGS__
   }
}

my $ftl      = File::Util->new();
my $tempdir  = tempdir( CLEANUP => 1 );
my $tempfile = $tempdir . SL . time . $$ . '.tmp';

$ftl->touch( $tempfile => { binmode => 'utf8' } );

is utf8::is_utf8( $ftl->load_file( $tempfile => { binmode => 'utf8' } ) ),
   1, 'file touched and read as UTF-8 strict';

unlink $tempfile or die $!;

$ftl->write_file( $tempfile => "\N{U+263A}" => { binmode => 'utf8' } );

is utf8::is_utf8( $ftl->load_file( $tempfile => { binmode => 'utf8' } ) ),
   1, 'file written and read as UTF-8 strict';

unlink $tempfile or die $!;

my $utf8fh = $ftl->open_handle( $tempfile => 'write' => { binmode => 'utf8' } );

print $utf8fh "\N{U+263A}" . NL;

$ftl->unlock_open_handle( $utf8fh );

close $utf8fh;

is utf8::is_utf8( $ftl->load_file( $tempfile => { binmode => 'utf8' } ) ),
   1, 'file written via file handle API and read as UTF-8 strict';

unlink $tempfile or die $!;

{
   local $@;

   eval { $ftl->write_file( $tempfile => "\N{U+263A}" ) };

   like $@,
      qr/wide character/mi,
      'writing unicode to a ":raw" filehandle fails';
}

isnt utf8::is_utf8( $ftl->load_file( $tempfile ) ),
   1, 'unicode written and read in :raw mode returns non-UTF-8 string';

is utf8::is_utf8( $ftl->load_file( $tempfile => { binmode => 'utf8' } ) ),
   1, 'unicode written in :raw and read in UTF-8 strict still treated as UTF-8';

$ftl->write_file( $tempfile => "\N{U+263A}" => { binmode => 'utf8' } );

$utf8fh = $ftl->open_handle( $tempfile => 'read' => { binmode => 'utf8' } );

is utf8::is_utf8( readline $utf8fh ),
   1, 'filehandle opened in UTF-8 strict, then lines read as UTF-8 strings';

$ftl->unlock_open_handle( $utf8fh );

close $utf8fh;

unlink $tempfile or die $!;

# XXX ... more tests coming

exit;

