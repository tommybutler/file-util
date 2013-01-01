
use strict;
use Test;
use File::Temp qw( tmpnam );

# use a BEGIN block so we print our plan before MyModule is loaded
BEGIN { plan tests => 2, todo => [] }

# load your module...
use lib './';
use File::Util;

# check object constructor
my $f = File::Util->new();

my $fn = tmpnam(); # get absolute filename

my $skip  = !$f->can_write( $f->return_path( $fn ) );

$skip = $skip ? &skipmsg() : $skip;

sub skipmsg { <<__WHYSKIP__ }
Insufficient permissions to perform IO on proposed temp file "$fn"
__WHYSKIP__

# test write
skip(
   $skip,
   sub {
      $f->write_file( file => $fn, content => 'JAPH' );
   },
   1, $skip
);

skip(
   $skip,
   sub { $f->load_file( $fn ) },
   'JAPH', $skip
);

exit;
