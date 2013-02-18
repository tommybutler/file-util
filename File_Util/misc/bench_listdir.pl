#!/usr/bin/perl

use strict;
use warnings;

use Time::HiRes;
use Benchmark::Forking qw( :all );

use lib './lib';
use lib '../lib';

use File::Util;
use File::Find::Rule;

my $f   = File::Util->new();

# some directory with no subdirs
my $nrdir = '/home/superman/nocloud/projects/personal/perl/CPAN/file-util/File_Util/lib/File/Util/Manual';

# some dir with several subdirs (and .pod files preferably)
my $dir = '/home/superman/nocloud/';

print "\nNON-RECURSIVE\n";
cmpthese
   10_000,
   {
      'File::Util'       => sub { $f->list_dir( $nrdir ) },
      'File::Find::Rule' => sub { File::Find::Rule->file->in( $nrdir ) },
   };

print "\nNON-RECURSIVE WITH REGEXES\n";
cmpthese
   10_000,
   {
      'File::Util'       => sub { $f->list_dir( $nrdir => { files_match => qr/\.pod$/ } ) },
      'File::Find::Rule' => sub { File::Find::Rule->file->name( qr/\.pod$/ )->in( $nrdir ) },
   };

print "\nRECURSIVE\n";
cmpthese
   200,
   {
      'File::Util'       => sub { $f->list_dir( $dir => { recurse => 1, files_only => 1 } ) },
      'File::Find::Rule' => sub { File::Find::Rule->file->in( $dir ) },
   };

print "\nRECURSIVE WITH REGEXES\n";
cmpthese
   200,
   {
      'File::Util'       => sub { $f->list_dir( $dir => { recurse => 1, files_only => 1, files_match => qr/\.pod$/ } ) },
      'File::Find::Rule' => sub { File::Find::Rule->file->name( qr/\.pod$/ )->in( $dir ) },
   };

__END__

typical results on my lowly laptop w/ intel i5 processor and pitifully slow hard drive

NON-RECURSIVE
                    Rate File::Find::Rule       File::Util
File::Find::Rule  4717/s               --             -75%
File::Util       18519/s             293%               --

NON-RECURSIVE WITH REGEXES
                   Rate File::Find::Rule       File::Util
File::Find::Rule 4292/s               --             -54%
File::Util       9346/s             118%               --

RECURSIVE
                   Rate       File::Util File::Find::Rule
File::Util       15.0/s               --             -45%
File::Find::Rule 27.4/s              83%               --

RECURSIVE WITH REGEXES
                   Rate       File::Util File::Find::Rule
File::Util       16.7/s               --             -41%
File::Find::Rule 28.2/s              69%               --


