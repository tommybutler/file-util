#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/superman/projects/personal/perl/CPAN/File_Util/File_Util/lib';

use File::Util;

print "$File::Util::VERSION\n";

my $f   = File::Util->new();
my $fn  = "/tmp/foo$$";
my $msg = "with love, from Paris, on ${\ scalar localtime }\n";

print '| ', join " | ", $f->atomize( $fn ); print " |\n";

my $fh = $f->open_handle( file => $fn, mode => 'write' );

print $fh $msg;

close $fh;

print "$fn contents: ", $f->load_file( $fn );

unlink $fn or warn "Couldn't unlink $fn => $!";

exit;
