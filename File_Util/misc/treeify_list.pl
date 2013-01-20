#!/usr/bin/perl

use warnings;
use strict;

use lib './lib';
use File::Util qw( atomize_path );

my @listing = (
   '/tmp/GTYzLxAEX8/20554/',
   '/tmp/GTYzLxAEX8/20554/1358653669/',
   '/tmp/GTYzLxAEX8/20554/1358653669/foo/',
   '/tmp/GTYzLxAEX8/20554/1358653669/foo/bar/',
   '/tmp/GTYzLxAEX8/20554/1358653669/a.txt',
   '/tmp/GTYzLxAEX8/20554/1358653669/b.log',
   '/tmp/GTYzLxAEX8/20554/1358653669/c.ini',
   '/tmp/GTYzLxAEX8/20554/1358653669/d.bat',
   '/tmp/GTYzLxAEX8/20554/1358653669/e.sh',
   '/tmp/GTYzLxAEX8/20554/1358653669/f.conf',
   '/tmp/GTYzLxAEX8/20554/1358653669/foo/bar/a.txt',
   '/tmp/GTYzLxAEX8/20554/1358653669/foo/bar/b.log',
   '/tmp/GTYzLxAEX8/20554/1358653669/foo/bar/c.ini',
   '/tmp/GTYzLxAEX8/20554/1358653669/foo/bar/d.bat',
   '/tmp/GTYzLxAEX8/20554/1358653669/foo/bar/e.sh',
   '/tmp/GTYzLxAEX8/20554/1358653669/foo/bar/f.conf',
   '/tmp/GTYzLxAEX8/20554/1358653669/foo/bar/g.bin',
   '/tmp/GTYzLxAEX8/20554/1358653669/foo/bar/h.rc',
   '/tmp/GTYzLxAEX8/20554/1358653669/g.bin',
   '/tmp/GTYzLxAEX8/20554/1358653669/h.rc'
);

my $tree = {};

for my $item ( @listing ) {

   my ( $root, $path, $file ) = atomize_path( $item );

   my @dirs = split /\//, $path;

   unshift @dirs, $root if $root;

   print qq( DIRS=@dirs | FILE=$file \n);
}




