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
say 'FILES single LEGACY regex "\.sh$|\.js$" (should produce 2 results)';
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
say 'FILES single match qr/\.sh$|\.js$/ (should produce 2 results)';
say for
$ftl->list_dir(
   $tempdir => {
      files_match => qr/\.sh$|\.js$/,
      files_only  => 1,
      recurse     => 1, # set to zero if you want to see diff output
      with_paths  => 1, # unnecessary if recurse => 1
      no_fsdots   => 1, # unnecessary if recurse => 1
   }
);

say '';
say 'FILES double OR match => [ qr/\.sh$/, qr/\.js$/ ] (should produce 2 results)';
say for
$ftl->list_dir(
   $tempdir => {
      files_match => { or => [ qr/\.sh$/, qr/\.js$/ ] },
      files_only  => 1,
      recurse     => 1, # set to zero if you want to see diff output
      with_paths  => 1, # unnecessary if recurse => 1
      no_fsdots   => 1, # unnecessary if recurse => 1
   }
);

say '';
say 'FILES double AND match [ qr/\.sh$/, qr/[[:alpha:]]\.\w\w/ ] (should only produce 1 result)';
say for
$ftl->list_dir(
   $tempdir => {
      files_match => { and => [ qr/\.sh$/, qr/[[:alpha:]]\.\w\w/ ] },
      files_only  => 1,
      recurse     => 1, # set to zero if you want to see diff output
      with_paths  => 1, # unnecessary if recurse => 1
      no_fsdots   => 1, # unnecessary if recurse => 1
   }
);

say '';
say 'DIRS single match /[xyz](?:foo|bar)/ (should only produce 2 results)';
say for
$ftl->list_dir(
   $tempdir => {
      dirs_match  => qr/[xyz](?:foo|bar)/,
      dirs_only   => 1,
      recurse     => 1,
   }
);

say '';
say 'DIRS single match /[xyz](?:foo|bar)/ + FILES single match /^[ijk]/ (should only produce 5 results)';
say for
$ftl->list_dir(
   $tempdir => {
      dirs_match  => qr/[xyz](?:foo|bar)/,
      files_match => qr/^[ijk]/,
      recurse     => 1,
   }
);

say '';
say 'DIRS double OR match qr/foo$/, qr/^zba/ + FILES double AND match qr/^[ab]/, qr/\.\w+/ (should produce 4 results)';
say for
$ftl->list_dir(
   $tempdir => {
      dirs_match  => { or  => [ qr/foo$/,  qr/^zba/  ] },
      files_match => { and => [ qr/^[ab]/, qr/\.\w+/ ] },
      recurse     => 1,
   }
);

say '';
say 'DIRS double OR match qr/^.foo/, qr/ar$/ + FILES double AND match qr/^[ij]/, qr/\.\w+/, with a callback';
say '...should produce several printed statements followed by 2 results';
say for
$ftl->list_dir(
   $tempdir => {
      dirs_match  => { or  => [ qr/^.foo/, qr/ar$/   ] },
      files_match => { and => [ qr/^[ij]/, qr/\.\w+/ ] },
      recurse     => 1,
      files_only  => 1,
      d_callback  => sub {
         my ( $dir, $subdirs ) = @_;
         say 'PWD!    => ' . $dir;
         say 'SUBDIR! => ' . $_ for @$subdirs;
         say 'SUBDIR! => -none-' unless @$subdirs;
         say '';
      },
   }
);

say '';
say 'FILES double AND match /^[ij]/, /\.\w{3}/ with PARENT double AND matches qr/^.b/, qr/ar$/ (should only produce 2 results)';
say for
$ftl->list_dir(
   $tempdir => {
      parent_matches => { and => [ qr/^.b/, qr/ar$/   ] },
      files_match  => { and => [ qr/^[ij]/, qr/\.\w{3}/ ] },
      recurse      => 1,
      files_only   => 1,
   }
);

say '';
say 'FILE single match /^[def]/ + PARENT single match /^[[:alnum:]\-_\.]{10}$/ (should produce 3 results)';
say for
$ftl->list_dir(
   $tempdir => {
      parent_matches => qr/^[[:alnum:]\-_\.]{10}$/,
      files_match  => qr/^[def]/,
      recurse      => 1,
      files_only   => 1,
   }
);

say '';
say 'FILE single match /^[jkl]/ + PARENT single match /^.bar$/ (should produce 3 results)';
say for
$ftl->list_dir(
   $tempdir => {
      parent_matches => qr/^.bar$/,
      files_match  => qr/^[jkl]/,
      recurse      => 1,
      files_only   => 1,
   }
);

say '';
say 'FILE legacy match "^[jk]" + PARENT /^.bar$/ match (should produce 2 results)';
say for
$ftl->list_dir(
   $tempdir => {
      parent_matches => qr/^.bar$/,
      rpattern     => '^[jk]',
      recurse      => 1,
      files_only   => 1,
   }
);

say '';
say 'MATCH FILES /[^ak]/ in PARENT /^[[:alnum:]\-_\.]{10}$/ -OR- /bar$/';
say '                                        - only 2 results exptected';
say for
$ftl->list_dir(
   $tempdir => {
      parent_matches => { or => [ qr/^[[:alnum:]\-_\.]{10}$/, qr/bar$/ ] },
      files_match  => qr/^[ak]/,
      recurse      => 1,
      files_only   => 1,
   }
);

say '';
say 'MATCH ANYTHING IN PATH [ /foo/ -AND- /bar$/ ]';
say for
$ftl->list_dir(
   $tempdir => {
      path_matches => { and => [ qr/foo/, qr/bar$/ ] },
      recurse      => 1,
   }
);

say '';
say 'MATCH ANYTHING IN PATH [ /foo$/ -OR- /bar$/ ]';
say for
$ftl->list_dir(
   $tempdir => {
      path_matches => { or => [ qr/foo$/, qr/bar$/ ] },
      recurse      => 1,
   }
);

say '';
say 'MATCH ANYTHING IN PATH [ /foo$/ -AND- /bar$/ ] (conflicting patterns; should produce 0 results)';
say for
$ftl->list_dir(
   $tempdir => {
      path_matches => { and => [ qr/foo$/, qr/bar$/ ] },
      recurse      => 1,
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

