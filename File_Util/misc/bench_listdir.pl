#!/usr/bin/perl

use strict;
use warnings;

use 5.10.0;
use Time::HiRes;
use Benchmark::Forking qw( :all );

use lib './lib';
use lib '../lib';

use File::Util;
use File::Find::Rule;

my $f   = File::Util->new();
my $nrdir = '/home/superman/nocloud/projects/personal/perl/CPAN/file-util/File_Util/lib/File/Util/Manual';
my $dir = '/home/superman/nocloud/';

say 'NON-RECURSIVE';
cmpthese
   10_000,
   {
      'File::Util'       => sub { $f->list_dir( $nrdir ) },
      'File::Find::Rule' => sub { File::Find::Rule->file->in( $nrdir ) },
   };

say '';
say 'NON-RECURSIVE WITH REGEXES';
cmpthese
   10_000,
   {
      'File::Util'       => sub { $f->list_dir( $nrdir => { files_match => qr/\.pod$/ } ) },
      'File::Find::Rule' => sub { File::Find::Rule->file->name( qr/\.pod$/ )->in( $nrdir ) },
   };

say '';
say 'RECURSIVE';
cmpthese
   200,
   {
      'File::Util'       => sub { $f->list_dir( $dir => { recurse => 1, files_only => 1 } ) },
      'File::Find::Rule' => sub { File::Find::Rule->file->in( $dir ) },
   };

say '';
say 'RECURSIVE WITH REGEXES';
cmpthese
   200,
   {
      'File::Util'       => sub { $f->list_dir( $dir => { recurse => 1, files_only => 1, files_match => qr/\.pod$/ } ) },
      'File::Find::Rule' => sub { File::Find::Rule->file->name( qr/\.pod$/ )->in( $dir ) },
   };

__END__

WITHOUT RECURSION: (File::Find::Rule gets spanked)

                   Rate File::Find::Rule       File::Util
File::Find::Rule 4137/s               --             -44%
File::Util       7446/s              80%               --

---

WITH RECURSION AND REGEXES (File::Util gets spanked)

                   Rate       File::Util File::Find::Rule
File::Util       16.7/s               --             -40%
File::Find::Rule 27.8/s              67%               --

