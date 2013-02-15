
use strict;
use warnings;
use Test::NoWarnings;
use Test::More tests => 4;
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

is $ftl->SL, SL, '...and it can proxy File::Util method calls';

exit;
