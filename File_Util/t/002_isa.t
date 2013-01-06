
use strict;
use warnings;

use Test::More tests => 2;
use Test::NoWarnings;

use lib './lib';
use File::Util;

my $f = File::Util->new();

# check to see if File::Util ISA [foo, etc.]
ok( UNIVERSAL::isa( $f, 'File::Util' ), 'ISA File::Util' );

exit;
