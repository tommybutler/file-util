#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/superman/projects/personal/perl/CPAN/File_Util/File_Util/lib';

use File::Util qw( atomize_path );

print "Rolling with File::Util v$File::Util::VERSION\n";

print_atomize( qw(
   C:\\foo\\bar\\baz.txt
   /foo/bar/baz.txt
   :a:b:c:d:e:f:g.txt
   ./a/b/c/d/e/f/g.txt
   ../wibble/wombat.ini
   ..\\woot\\noot.doc
   ../../zoot.conf
   /root
   /etc/sudoers
   /
   D:\\
   D:\\autorun.inf
) );

sub print_atomize {
   my $fmt = qq{ %-25s %-10s %-25s %-18s\n};
   print '-' x 80, "\n";
   printf $fmt, qw( INPUT ROOT PATH-COMPONENT FILE/DIR );
   print '-' x 80, "\n";
   printf $fmt, $_, atomize_path $_ for @_;
}
