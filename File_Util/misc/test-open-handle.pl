#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/superman/projects/personal/perl/CPAN/File_Util/File_Util/lib';

use File::Util;

print "$File::Util::VERSION\n";

my $f   = File::Util->new();
my $fn  = "/tmp/foo$$";
my $msg = <<__MSG__;
with love, from Paris, on ${\ scalar localtime }
...or adulation, from Antares, some time in the future
__MSG__

my $fh = $f->open_handle( file => $fn, mode => 'write' );

print $fh $msg;

close $fh;

$fh = $f->open_handle( file => $fn,  mode => 'read' );

my $i = 0; ++$i and print "$fn contents line $i: $_" while <$fh>;

close $fh;

unlink $fn or warn "Couldn't unlink $fn => $!";

exit;
