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

say '';
say 'FILES single match with LEGACY regex or|or (should produce 2 results)';
say for
$ftl->list_dir(
   $tempdir => {
      rpattern    => '\.sh$|\.js$',
      files_only  => 1,
      recurse     => 1, # set to zero if you want to see diff output
      with_paths  => 1, # unnecessary if recurse => 1
      no_fsdots   => 1, # unnecessary if recurse => 1
   }
);

say '';
say 'FILES single match with regex or|or (should produce 2 results)';
say for
$ftl->list_dir(
   $tempdir => {
      #match_files => { or => [ qr/\.sh$/, qr/\.js$/ ] },
      #match_files => { and => [ qr/\.sh$/, qr/\w\./ ] },
      match_files => qr/\.sh$|\.js$/,
      files_only  => 1,
      recurse     => 1, # set to zero if you want to see diff output
      with_paths  => 1, # unnecessary if recurse => 1
      no_fsdots   => 1, # unnecessary if recurse => 1
   }
);

say '';
say 'FILES double match with OR => [ regex, regex ] (should produce 2 results)';
say for
$ftl->list_dir(
   $tempdir => {
      match_files => { or => [ qr/\.sh$/, qr/\.js$/ ] },
      #match_files => { and => [ qr/\.sh$/, qr/\w\./ ] },
      #match_files => qr/\.sh$|\.js$/,
      files_only  => 1,
      recurse     => 1, # set to zero if you want to see diff output
      with_paths  => 1, # unnecessary if recurse => 1
      no_fsdots   => 1, # unnecessary if recurse => 1
   }
);

say '';
say 'FILES double match with AND => [ regex, regex ] (should only produce 1 result)';
say for
$ftl->list_dir(
   $tempdir => {
      #match_files => { or => [ qr/\.sh$/, qr/\.js$/ ] },
      match_files => { and => [ qr/\.sh$/, qr/[[:alpha:]]\.\w\w/ ] },
      #match_files => qr/\.sh$|\.js$/,
      files_only  => 1,
      recurse     => 1, # set to zero if you want to see diff output
      with_paths  => 1, # unnecessary if recurse => 1
      no_fsdots   => 1, # unnecessary if recurse => 1
   }
);

say '';
say 'DIRS single match (should only produce 2 results)';
say for
$ftl->list_dir(
   $tempdir => {
      match_dirs  => qr/[xyz](?:foo|bar)/,
      dirs_only   => 1,
      recurse     => 1,
   }
);

say '';
say 'DIRS+FILES single matches (should only produce 8 results)';
say for
$ftl->list_dir(
   $tempdir => {
      match_dirs  => qr/[xyz](?:foo|bar)/,
      match_files => qr/^[abcijk]/,
      recurse     => 1,
   }
);

say '';
say 'DIRS+FILES double OR+AND matches (should only produce 4 results)';
say for
$ftl->list_dir(
   $tempdir => {
      match_dirs  => { or  => [ qr/foo$/,  qr/^zba/  ] },
      match_files => { and => [ qr/^[ab]/, qr/\.\w+/ ] },
      recurse     => 1,
   }
);

say '';
say 'DIRS+FILES double OR+AND matches with a callback (should only produce 2 results)';
say for
$ftl->list_dir(
   $tempdir => {
      match_dirs  => { and => [ qr/^.(?:foo|bar)/,  qr/oo$|ar$/  ] },
      match_files => { and => [ qr/^[ij]/, qr/\.\w+/ ] },
      recurse     => 1,
      files_only  => 1,
      d_callback  => sub {
         my ( $dir, $subdirs ) = @_;
         say 'PWD! => ' . $dir;
         say 'SUBDIR! => ' . $_ for @$subdirs;
         say '';
      },
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

