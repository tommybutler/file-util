
use strict;
use warnings;
use Test::More tests => 9;
use Test::NoWarnings;

use Fcntl qw( );
use File::Temp qw( tmpnam );

use lib './lib';
use File::Util qw( SL NL OS );

my $f = File::Util->new( '--fatals-as-status' );

my ( $tfh, $tmpf ) = tmpnam();

close $tfh;   # I didn't want it opened!
unlink $tmpf; # ^^ our auto-flock won't work on duped FH

my $have_flock = sub {

   local $@;

   eval {
      flock( STDIN, &Fcntl::LOCK_SH );
      flock( STDIN, &Fcntl::LOCK_UN );
   };

   return $@ ? 0 : 1;
}->();

my $have_perms = $f->can_write( $f->return_path( $tmpf ) );

SKIP: {

   if ( !$have_flock ) {

      skip 'Your system cannot flock' => 8;
   }
   elsif ( !$have_perms ) {

      skip 'Insufficient permissions' => 8;
   }
   elsif ( $^O =~ /solaris|sunos/i ) {

      skip 'Solaris flock has issues' => 8;
   }

   # flock-ing usage toggles
   ok( $f->use_flock( ) == 1, 'test flock on' );       # test 1
   ok( $f->use_flock(1) == 1, 'test on toggle' );      # test 2
   ok( $f->use_flock(0) == 0, 'test off toggle' );     # test 3
   ok( $f->use_flock( ) == 0, 'test toggled off' );    # test 4
   ok( $f->use_flock(1) == 1, 'test toggle back on' ); # test 5

   # get/set flock-ing failure policy
   ok(                                                 # test 6
      join( ' ', $f->flock_rules() ) eq 'NOBLOCKEX FAIL',
      'expecting ' . join( ' ', $f->flock_rules() )
   );

   ok(                                                 # test 7
      join( ' ', $f->flock_rules( qw/ NOBLOCKEX ZERO / ) ) eq 'NOBLOCKEX ZERO',
      'expecting ' . join( ' ', $f->flock_rules( qw/ NOBLOCKEX ZERO / ) )
   );

   # actual flock test
   ok( fight_for_lock() == 0, 'contending OPs must fail' ); # test 8

}

unlink $tmpf;

exit;

# put flock to the "test"
sub fight_for_lock {

   # auto-locks file, keep open handle on it
   my $fh = $f->open_handle( file => $tmpf );

   # this should fail, and return a "0" instead of a filehandle
   return $f->open_handle( file => $tmpf );
}
