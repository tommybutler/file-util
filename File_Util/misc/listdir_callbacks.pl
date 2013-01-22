#!/usr/bin/perl

use warnings;
use strict;
use 5.10.0;

use Time::HiRes;
use File::Temp qw( tempdir );

use lib './lib';
use File::Util qw( SL );

my $ftl = File::Util->new( { fatals_as_status => 1 } );

my $tempdir = tempdir( CLEANUP => 1 );

setup_test_tree();

my $d_cb = sub
{
   my ( $dir, $subdirs ) = @_;

   print qq(SUBDIRS IN $dir\n);
   print "   - none\n\n" and return unless @$subdirs;
   print "   - $_\n" for @$subdirs;
   print "\n";

   return;
};

my $f_cb = sub
{
   my ( $dir, $files ) = @_;

   print qq(FILES in $dir\n);
   print "   - none\n\n" and return unless @$files;
   print "   - $_ - @{[ -s $_ ]} bytes\n" for @$files;
   print "\n";

   return;
};

my $cb = sub {
   my ( $dir, $subdirs, $files ) = @_;

   $subdirs = scalar @$subdirs;
   $files   = scalar @$files;

   say qq(TOTALS IN: $dir - $subdirs directories | $files files\n);
};

$ftl->list_dir(
   $tempdir => {
      d_callback  => $d_cb,
      f_callback  => $f_cb,
      callback    => $cb,
      recurse     => 1, # set to zero if you want to see diff output
      with_paths  => 1, # unnecessary if recurse => 1
      no_fsdots   => 1, # unnecessary if recurse => 1
   }
);

exit;

sub setup_test_tree {

   my @test_files  = qw(
      a.txt   b.log
      c.ini   d.bat
      e.sh    f.conf
      g.bin   h.rc
   );

   for my $tfile ( @test_files )
   {
      $ftl->touch( $tempdir . SL . $tfile );
   }

   my $deeper = $tempdir . SL . 'xfoo' . SL . 'zbar';

   $ftl->make_dir( $deeper );

   @test_files = qw(
      i.jpg   j.xls
      k.ppt   l.scr
      m.html  n.js
      o.css   p.avi
   );

   for my $tfile ( @test_files )
   {
      $ftl->write_file( { file => $deeper . SL . $tfile, content => rand } );
   }

   return;
}

