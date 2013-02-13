
use strict;
use warnings;

# the original intent of this test was to isolate and test solely the
# list_dir method, but it became immediatley apparent that you can't
# very well test list_dir() unless you have a good directory tree first;
# this led to the combining of the make_dir and list_dir testing routines

use Test::More tests => 24;
use Test::NoWarnings;

use File::Temp qw( tempdir );

use lib './lib';
use File::Util qw( SL NL );

# one recognized instantiation setting
my $ftl = File::Util->new( );

my $tempdir     = tempdir( CLEANUP => 1 );
my $testbed     = $tempdir . SL . $$ . SL . time;
my $tmpf        = $testbed . SL . 'tmptest';
my $have_perms  = $ftl->is_writable( $tempdir );
my @test_files  = qw/
   a.txt   b.log
   c.ini   d.bat
   e.sh    f.conf
   g.bin   h.rc
/;

for my $tfile ( @test_files )
{
   ok(
      $ftl->touch( $testbed . SL . $tfile ) == 1,
      'create files in a directory that does not exist beforehand'
   );
}

is_deeply
(
   [ sort $ftl->list_dir( $testbed, '--recurse' ) ],
   [ sort map { $testbed . SL . $_ } @test_files ],
   'test recursive listing with classic call style arguments'
);

my $deeper = $testbed . SL . 'foo' . SL . 'bar';

# make a deeper directory
is
(
   $ftl->make_dir( $deeper ), $deeper,
   'make a deeper directory'
);

for my $tfile ( @test_files )
{
   ok
   (
      $ftl->touch( $deeper . SL . $tfile ) == 1,
      'create files in a abs path directory that already exists'
   );
}

is_deeply
(
   [ sort $ftl->list_dir( $deeper => { recurse => 1 } ) ],
   [ sort map { $deeper . SL . $_ } @test_files ],
   'test recursive file listing with modern call style'
);

is_deeply
(
   [ sort $ftl->list_dir( $deeper, '--recurse'  ) ],
   [ sort map { $deeper . SL . $_ } @test_files ],
   'test recursive file listing with classic call style'
);

is_deeply
(
   [
      sort map { $ftl->strip_path( $_ ) } $ftl->list_dir
      (
         $testbed => { recurse => 1, files_only => 1 }
      )
   ],
   [ sort @test_files, @test_files  ],
   'same, but using modern call style, ' .
   'stripped of fully qualified paths'
);

is_deeply
(
   [
      sort map { $ftl->strip_path( $_ ) } $ftl->list_dir
      (
         $testbed => { recurse => 1 }, { files_only => 1 }
      )
   ],
   [ sort @test_files, @test_files  ],
   'same, but using intentially wrong modern call style, ' .
   'stripped of fully qualified paths'
);

my @cbstack;

sub callback
{
   my ( $currdir, $subdirs, $files, $depth ) = @_;

   push @cbstack, @$subdirs;
   push @cbstack, @$files;

   return;
}

$ftl->list_dir( $tempdir => { callback => \&callback, recurse => 1 } );

my @list_as_lines = $ftl->list_dir( $tempdir => { recurse => 1 } );

is_deeply
   [ sort { uc $a cmp uc $b } @cbstack ],
   [ sort { uc $a cmp uc $b } @list_as_lines ],
   'compare recursive listing to recursive callback return';

exit;

