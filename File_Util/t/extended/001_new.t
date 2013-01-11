
use strict;
use warnings;

use Test::More tests => 25;
use Test::NoWarnings;

use lib './lib';
use File::Util;

my $ftl;

# one recognized instantiation setting
$ftl = File::Util->new( use_flock => 0 );
ok( ref $ftl eq 'File::Util' );
ok( $ftl->use_flock == 0 );

# another recognized instantiation setting
$ftl = File::Util->new( readlimit => 1234567890 );
ok( ref $ftl eq 'File::Util' );
ok( $ftl->readlimit == 1234567890 );

# yet another recognized instantiation setting
$ftl = File::Util->new( max_dives => 9876543210 );
ok( ref $ftl eq 'File::Util' );
ok( $ftl->max_dives == 9876543210 );

# all recognized per-instantiation settings
$ftl = File::Util->new(
   use_flock => 1,
   readlimit => 1111111,
   max_dives => 2222222
);
ok( ref $ftl eq 'File::Util' );
ok( $ftl->use_flock == 1 );
ok( $ftl->readlimit == 1111111 );
ok( $ftl->max_dives == 2222222 );

# one recognized flag
$ftl = File::Util->new( '--fatals-as-warning' );
ok( ref $ftl eq 'File::Util' );
ok( $ftl->{opts}{fatals_as_warning} == 1 );

# another recognized flag
$ftl = File::Util->new( '--fatals-as-status' );
ok( ref $ftl eq 'File::Util' );
ok( $ftl->{opts}{fatals_as_status} == 1 );

# yet another recognized flag
$ftl = File::Util->new( '--fatals-as-errmsg' );
ok( ref $ftl eq 'File::Util' );
ok( $ftl->{opts}{fatals_as_errmsg} == 1 );

# all settings and one recognized flag
$ftl = File::Util->new(
   use_flock => 0,
   readlimit => 1111111,
   max_dives => 2222222,
   '--fatals-as-status',
   '--warn-also'
);
ok( ref $ftl eq 'File::Util' );
ok( $ftl->use_flock == 0 );
ok( $ftl->readlimit == 1111111 );
ok( $ftl->max_dives == 2222222 );
ok( $ftl->{opts}{fatals_as_status} == 1 );
ok( $ftl->{opts}{warn_also} == 1 );
ok( !defined $ftl->{opts}{fatals_as_warning} );
ok( !defined $ftl->{opts}{fatals_as_errmsg} );

exit;
