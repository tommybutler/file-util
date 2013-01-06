
use strict;
use warnings;
use Test::More tests => 36;
use Test::NoWarnings;

use lib './lib';
use File::Util qw( SL OS );

my $f = File::Util->new();

my @fls = ( qq[t${\SL}txt], qq[t${\SL}bin], 't', '.', '..' );

# types
is_deeply( [ $f->file_type( $fls[0] ) ], [ qw( PLAIN TEXT ) ] );
is_deeply( [ $f->file_type( $fls[1] ) ], [ qw( PLAIN BINARY ) ] );

# file is/isn't binary
ok( $f->isbin( $fls[1], 1 ) );
ok( !$f->isbin(__FILE__) );

for my $file ( @fls ) {

   # get file size
   ok( $f->size( $file ) == -s $file );

   # get file creation time
   ok( $f->created( $file ) == $^T - ((-M $file) * 60 * 60 * 24) );

   # get file last access time
   ok( $f->last_access( $file ) == $^T - ((-A $file) * 60 * 60 * 24) );

   # get file last modified time
   ok( $f->last_modified( $file ) == $^T - ((-M $file) * 60 * 60 * 24) );

   # get file's bitmask
   ok( $f->bitmask( $file ) eq sprintf('%04o',(stat($file))[2] & 0777) );
}

SKIP: {
   skip 'these tests not performed on window$', 3 if OS eq 'WINDOWS';

   is_deeply( [ $f->file_type( $fls[2] ) ], [ qw( BINARY DIRECTORY ) ] );
   is_deeply( [ $f->file_type( $fls[3] ) ], [ qw( BINARY DIRECTORY ) ] );
   is_deeply( [ $f->file_type( $fls[4] ) ], [ qw( BINARY DIRECTORY ) ] );
}

is( ( $f->file_type( $fls[2] ) )[-1], 'DIRECTORY' );
is( ( $f->file_type( $fls[3] ) )[-1], 'DIRECTORY' );
is( ( $f->file_type( $fls[4] ) )[-1], 'DIRECTORY' );

exit;
