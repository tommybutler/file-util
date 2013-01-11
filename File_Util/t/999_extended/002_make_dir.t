
use strict;
use warnings;

use Test::More tests => 1;
use Test::NoWarnings;

use File::Temp qw( tempdir );

use lib './lib';
use File::Util qw( SL );

# one recognized instantiation setting
my $ftl = File::Util->new( );

#my $tempdir    = tempdir( CLEANUP => 1 );
my $tempdir    = tempdir(  );
my $testbed    = $tempdir . SL . $$ . SL . time;
my $tmpf       = $testbed . SL . 'tmptest';
my $have_perms = $ftl->can_write( $tempdir );
my @testfiles  = qw/ a.txt b.log c.ini d.bat e.sh f.conf /;

for my $testfile ( @testfiles ) {

   ok( $ftl->touch( $testbed . SL . $testfile ) == 1 );
}

is_deeply(
   [ $ftl->list_dir( $testbed, '--recurse', '--with-paths' ) ],
   [ join $testbed . SL, @testfiles ]
);

exit;

