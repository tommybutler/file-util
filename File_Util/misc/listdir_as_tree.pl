#!/usr/bin/perl
use 5.10.0;
use warnings;
use strict;

use File::Temp qw( tempdir );

use lib './lib';
use File::Util qw( SL );

my $ftl = File::Util->new( { fatals_as_status => 1 } );

my $tempdir = tempdir( CLEANUP => 1 );

setup_test_tree();

say 'ALL FILES RECURSIVELY:';
say for $ftl->list_dir( $tempdir => { recurse => 1 } );

print "\n\n";

use Data::Dumper;
   $Data::Dumper::Purity   = 1;
   $Data::Dumper::Indent   = 2;
   $Data::Dumper::Terse    = 1;
   $Data::Dumper::Sortkeys = 1;

say 'AS TREE';
print Dumper $ftl->list_dir(
   $tempdir => {
      as_tree => 1,
      recurse => 1,
   }
);

say 'AS TREE, WITHOUT DIRMETA, MATCHING FILES /^[abcjkl]/';
print Dumper $ftl->list_dir(
   $tempdir => {
      as_tree     => 1,
      recurse     => 1,
      no_dirmeta  => 1,
      files_match => qr/^[abcjkl]/,
   }
);

say 'AS TREE, WITHOUT DIRMETA, LEGACY-STYLE MATCHING FILES /^[jbc]/, MATCHING PARENT /bar$/';
print Dumper $ftl->list_dir(
   $tempdir => {
      as_tree    => 1,
      recurse    => 1,
      no_dirmeta => 1,
      rpattern   => '^[jbc]',
      parent_matches => qr/bar$/,
   }
);

say 'AS TREE, WITHOUT DIRMETA, MATCHING FILES /^[ak]/, MATCHING PARENT /^[[:alnum:]\-_\.]{10}$/ -OR- /oo$/';
print Dumper $ftl->list_dir(
   $tempdir => {
      as_tree      => 1,
      recurse      => 1,
      no_dirmeta   => 1,
      files_match  => qr/^[ak]/,
      parent_matches => { or => [ qr/^[[:alnum:]\-_\.]{10}$/, qr/oo$/ ] },
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
      $ftl->touch( $deeper . SL . $tfile );
   }

   return;
}

__END__

When run, this code produces output like the following:

/tmp/jGc6shUGSr/xfoo
/tmp/jGc6shUGSr/xfoo/zbar
/tmp/jGc6shUGSr/a.txt
/tmp/jGc6shUGSr/b.log
/tmp/jGc6shUGSr/c.ini
/tmp/jGc6shUGSr/d.bat
/tmp/jGc6shUGSr/e.sh
/tmp/jGc6shUGSr/f.conf
/tmp/jGc6shUGSr/g.bin
/tmp/jGc6shUGSr/h.rc
/tmp/jGc6shUGSr/xfoo/zbar/i.jpg
/tmp/jGc6shUGSr/xfoo/zbar/j.xls
/tmp/jGc6shUGSr/xfoo/zbar/k.ppt
/tmp/jGc6shUGSr/xfoo/zbar/l.scr
/tmp/jGc6shUGSr/xfoo/zbar/m.html
/tmp/jGc6shUGSr/xfoo/zbar/n.js
/tmp/jGc6shUGSr/xfoo/zbar/o.css
/tmp/jGc6shUGSr/xfoo/zbar/p.avi

{
  '/' => {
           '_DIR_PARENT_' => undef,
           '_DIR_SELF_' => '/',
           'tmp' => {
                      '_DIR_PARENT_' => '/',
                      '_DIR_SELF_' => '/tmp',
                      'jGc6shUGSr' => {
                                        '_DIR_PARENT_' => '/tmp',
                                        '_DIR_SELF_' => '/tmp/jGc6shUGSr',
                                        'a.txt' => '/tmp/jGc6shUGSr/a.txt',
                                        'b.log' => '/tmp/jGc6shUGSr/b.log',
                                        'c.ini' => '/tmp/jGc6shUGSr/c.ini',
                                        'd.bat' => '/tmp/jGc6shUGSr/d.bat',
                                        'e.sh' => '/tmp/jGc6shUGSr/e.sh',
                                        'f.conf' => '/tmp/jGc6shUGSr/f.conf',
                                        'g.bin' => '/tmp/jGc6shUGSr/g.bin',
                                        'h.rc' => '/tmp/jGc6shUGSr/h.rc',
                                        'xfoo' => {
                                                    '_DIR_PARENT_' => '/tmp/jGc6shUGSr',
                                                    '_DIR_SELF_' => '/tmp/jGc6shUGSr/xfoo',
                                                    'zbar' => {
                                                                '_DIR_PARENT_' => '/tmp/jGc6shUGSr/xfoo',
                                                                '_DIR_SELF_' => '/tmp/jGc6shUGSr/xfoo/zbar',
                                                                'i.jpg' => '/tmp/jGc6shUGSr/xfoo/zbar/i.jpg',
                                                                'j.xls' => '/tmp/jGc6shUGSr/xfoo/zbar/j.xls',
                                                                'k.ppt' => '/tmp/jGc6shUGSr/xfoo/zbar/k.ppt',
                                                                'l.scr' => '/tmp/jGc6shUGSr/xfoo/zbar/l.scr',
                                                                'm.html' => '/tmp/jGc6shUGSr/xfoo/zbar/m.html',
                                                                'n.js' => '/tmp/jGc6shUGSr/xfoo/zbar/n.js',
                                                                'o.css' => '/tmp/jGc6shUGSr/xfoo/zbar/o.css',
                                                                'p.avi' => '/tmp/jGc6shUGSr/xfoo/zbar/p.avi'
                                                              }
                                                  }
                                      }
                    }
         }
}

