
use strict;
use warnings;

use Test::More tests => 28;
use Test::NoWarnings ':early';

use lib './lib';
use File::Util;

my $ftl;

# one recognized instantiation setting
$ftl = File::Util->new( use_flock => 0 );
ok
(
   ref $ftl eq 'File::Util',
   'new() is blessed correctly after flock toggle invocation'
);

ok
(
   $ftl->use_flock == 0,
   'flock off-toggle sticks after blessing'
);

# another recognized instantiation setting
$ftl = File::Util->new( readlimit => 1234567890 );
ok
(
   ref $ftl eq 'File::Util',
   'new() is blessed correctly after readlimit-set invocation'
);

ok
(
   $ftl->readlimit == 1234567890,
   'readlimit setting sticks after blessing'
);

# yet another recognized instantiation setting
$ftl = File::Util->new( max_dives => 9876543210 );
ok
(
   ref $ftl eq 'File::Util',
   'new() is blessed right after max_dives-set invocation'
);

ok
(
   $ftl->max_dives == 9876543210,
   'max_dives toggle sticks after max_dives-set invocation'
);

# all recognized per-instantiation settings
$ftl = File::Util->new
(
   use_flock => 1,
   readlimit => 1111111,
   max_dives => 2222222
);

ok
(
   ref $ftl eq 'File::Util',
   'new() blessed right with multi-toggle'
);

ok
(
   $ftl->use_flock == 1,
   'use_flock sticks after multi-toggle'
);

ok
(
   $ftl->readlimit == 1111111,
   'readlimit sticks after multi-toggle blessing'
);

ok
(
   $ftl->max_dives == 2222222,
   'max_dives sticks after multi-toggle blessing'
);

# one recognized flag
$ftl = File::Util->new( '--fatals-as-warning' );
ok
(
   ref $ftl eq 'File::Util', 'new() blessed right with fatals toggle'
);

ok
(
   $ftl->{opts}{fatals_as_warning} == 1,
   'modern internal setting matches toggle'
);

ok
(
   $ftl->{opts}{'--fatals-as-warning'} == 1,
   'classic internal setting matches toggle'
);

# another recognized flag
$ftl = File::Util->new( '--fatals-as-status' );
ok( ref $ftl eq 'File::Util' );
ok( $ftl->{opts}{fatals_as_status} == 1 ); # peek at internals
ok( $ftl->{opts}{'--fatals-as-status'} == 1 ); # peek at internals

# yet another recognized flag
$ftl = File::Util->new( '--fatals-as-errmsg' );
ok( ref $ftl eq 'File::Util' );
ok( $ftl->{opts}{fatals_as_errmsg} == 1 ); # peek at internals
ok( $ftl->{opts}{'--fatals-as-errmsg'} == 1 ); # peek at internals

# all settings and one recognized flag, using ::Modern syntax
$ftl = File::Util->new(
   {
      use_flock => 0,
      readlimit => 1111111,
      max_dives => 2222222,
      fatals_as_status => 1,
      warn_also => 1
   }
);
ok( ref $ftl eq 'File::Util' );
ok( $ftl->use_flock == 0 );
ok( $ftl->readlimit == 1111111 );
ok( $ftl->max_dives == 2222222 );
ok( $ftl->{opts}{fatals_as_status} == 1 );      # peek at internals
ok( $ftl->{opts}{warn_also} == 1 );             # peek at internals
ok( !defined $ftl->{opts}{fatals_as_warning} );
ok( !defined $ftl->{opts}{fatals_as_errmsg} );

exit;
