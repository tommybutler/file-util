use strict;
use Test;

# use a BEGIN block so we print our plan before MyModule is loaded
BEGIN { plan tests => 1, todo => [] }
BEGIN { $| = 1 }

# load your module...
use lib './';
use File::Util;

my $f = File::Util->new();

# check to see if File::Util ISA [foo, etc.]
ok( UNIVERSAL::isa( $f, 'File::Util' ) );

exit;
