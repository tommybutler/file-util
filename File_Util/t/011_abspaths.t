
use strict;
use warnings;
use Test::More tests => 3;
use Test::NoWarnings;
use File::Temp qw( tmpnam );

use lib './lib';
use File::Util;

# check object constructor
my $f = File::Util->new();

my $fn = tmpnam(); # get absolute filename

my $skip  = !$f->can_write( $f->return_path( $fn ) );

$skip = $skip ? &skipmsg() : $skip;

sub skipmsg { <<__WHYSKIP__ }
Insufficient permissions to perform IO on proposed temp file "$fn"
__WHYSKIP__

SKIP: {
   skip $skip, 2 if $skip;

   # test write
   ok( $f->write_file( file => $fn, content => 'JAPH' ) == 1 );

   ok( $f->load_file( $fn ) eq 'JAPH' );
}

unlink $fn;

exit;
