
use strict;
use warnings;
use Test::More tests => 14;
use Test::NoWarnings;

use File::Temp qw( tempdir );

use lib './lib';
use File::Util qw( SL NL existent OS );

my $f          = File::Util->new();
my $tempdir    = tempdir( CLEANUP => 1 );
my $testbed    = $tempdir . SL . $$ . SL . time;
my $tmpf       = $testbed . SL . 'tmptest';
my $have_perms = $f->can_write( $tempdir );
my $testfh;

SKIP: {

   if ( !$have_perms ) {

      skip 'Insufficient permissions to perform IO in tempdir' => 13;
   }
   elsif ( !solaris_cooperates() ) {

      skip 'Testing with an incooperative Solaris installation' => 13;
   }

   # 1
   # make a temporary testbed directory
   is( $f->make_dir( $testbed, '--if-not-exists' ), $testbed );

   # 2
   # see if it's there
   is( -e $testbed, 1 );

   # 3
   # ...again
   is( $f->existent( $testbed ), 1 );

   # 4
   # make a temporary file
   is( $f->write_file( file => $tmpf, content => 'LARRY' ), 1 );

   # 5
   # File::Util::touch() a file, and see if it was created ok
   is(
      sub {
           my $tmpf = $testbed . SL . 'touched';

           $f->touch( $tmpf );

           my $result = $f->existent( $tmpf );

           unlink $tmpf;

           return $result;
      }->(), 1
   );

   # 6
   # get an open file handle
   is(
      sub {
         $testfh = $f->open_handle(
            file => $tmpf,
            mode => 'append',
            qw( --fatals-as-errmsg --warn-also )
         );

         return ref $testfh
      }->(), 'GLOB'
   );

   # 7
   # make sure it's still open
   ok( defined fileno $testfh );

   # write to it, close it, write to it in append mode
   print $testfh 'WALL' and close $testfh;

   # 8
   # load file
   is( $f->load_file( $tmpf ), 'LARRYWALL' );

   # 9
   # write to it with method File::Util::write_file(), compare file contents
   # with the returned value
   is(
      sub {
         $f->write_file(
            filename => $tmpf,
            content  => OS . NL
         );

         return $f->load_file( $tmpf ); }->(),
      OS . NL
   );

   # 10
   # get line count of file
   is( $f->line_count( $tmpf ), 1 );

   # 11
   # truncate file
   is ( sub { $f->trunc( $tmpf ); return -s $tmpf }->(), 0 );

   # 12
   # get line count of file
   ok( $f->line_count( $tmpf ) == 0 );

   # big directory creation / removal sequence
   my $newdir = $testbed
     . SL . int( rand time )
     . SL . int( rand time )
     . SL . int( rand time )
     . SL . int( rand time );

   # 13
   # make directories
   is( $f->make_dir( $newdir, '--if-not-exists' ), $newdir );
}

exit;

sub solaris_cooperates {

   # we're only probing for solaris here, which has known issues
   return 1 if $^O !~ /solaris|sunos/i;

   my $tmpf = $tempdir . SL . 'solaris';

   my $f  = File::Util->new( '--fatals-as-status' );

   my $fh = $f->open_handle( file => $tmpf );

   my $ok = fileno $fh ? 1 : 0;

   close $fh if $ok;

   unlink $tmpf if $ok;

   return $ok;
}
