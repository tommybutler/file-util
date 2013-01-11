
use strict;
use warnings;

# the original intent of this test was to isolate and test solely the
# list_dir method, but it became immediatley apparent that you can't
# very well test list_dir() unless you have a good directory tree first;
# this led to the combining of the make_dir and list_dir testing routines

use Test::More tests => 20;
use Test::NoWarnings;

use File::Temp qw( tempdir );

use lib './lib';
use File::Util qw( SL NL );

# one recognized instantiation setting
my $ftl = File::Util->new( );

my $tempdir    = tempdir( CLEANUP => 1 );
my $testbed    = $tempdir . SL . $$ . SL . time;
my $tmpf       = $testbed . SL . 'tmptest';
my $have_perms = $ftl->can_write( $tempdir );
my @testfiles  = qw/
   a.txt   b.log
   c.ini   d.bat
   e.sh    f.conf
   g.bin   h.rc
/;

# touch files in directories that don't exist yet (File::Util will create them)
for my $tfile ( @testfiles ) {

   ok( $ftl->touch( $testbed . SL . $tfile ) == 1 );
}

is_deeply(
   [ sort $ftl->list_dir( $testbed, '--recurse' ) ], # classic call style
   [ sort map { $testbed . SL . $_ } @testfiles ]
);

#use Data::Dumper;
#print Dumper [ sort $ftl->list_dir( $testbed, '--recurse', '--with-paths' ) ];
#print Dumper [ sort map { $testbed . SL . $_ } @testfiles ];

my $deeper = $testbed . SL . 'foo' . SL . 'bar';

#print $deeper . NL;

# make a deeper directory
is( $ftl->make_dir( $deeper ), $deeper );

# create files in a directory that already exists
for my $tfile ( @testfiles ) {

   ok( $ftl->touch( $deeper . SL . $tfile ) == 1 );
}

is_deeply(
   [ sort $ftl->list_dir( $deeper => { recurse => 1 } ) ], # modern call style
   [ sort map { $deeper . SL . $_ } @testfiles ]
);

#use Data::Dumper;
#print Dumper [ sort $ftl->list_dir( $deeper, '--recurse' ) ];
#print Dumper [ sort map { $deeper . SL . $_ } @testfiles ];
#print Dumper [ $ftl->list_dir( $testbed => { recurse => 1, as_ref => 1 } ) ];

#is_deeply(
#   [ sort $ftl->list_dir( $testbed, '--recurse' ) ],
#   [
#      qw/
#      /
#   ]
#);

exit;

