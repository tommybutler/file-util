
use strict;
use warnings;
use Test::More;

if ( $ENV{RELEASE_TESTING} || $ENV{AUTHOR_TESTING} || $ENV{AUTHOR_TESTS} )
{                            # the tests in this file have nothing to do with
   plan tests => 4;          # end users of File::Util

   CORE::eval # hide the eval...
   '
use Test::NoWarnings;
   '; # ...from dist parsers
}
else
{
   plan skip_all => 'these tests are for testing by the author';
}


use File::Temp qw( tempdir );

use lib './lib';

use File::Util qw( SL );
use File::Util::ProxyLog;


my $dir = tempdir( CLEANUP => 1 );
my $log = $dir . SL . 'File-Util.log';

my $ftu = File::Util->new();
my $ftl = File::Util::ProxyLog->new( $ftu, $log );

isa_ok $ftl, 'File::Util::ProxyLog', 'File::Util::ProxyLog object is a File::Util::ProxyLog object';

isa_ok $$ftl, 'File::Util', '...and it is also a reference to a File::Util object';

is $ftl->is_readable('.'), 1, '...and it can proxy File::Util method calls';

exit;
