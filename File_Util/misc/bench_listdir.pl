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
#my $dir = '/home/superman/nocloud/projects/personal/perl/CPAN/file-util/File_Util/lib/File/Util/Manual';
my $dir = '/home/superman/nocloud/';

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

WITH RECURSION (File::Util gets spanked)

                   Rate       File::Util File::Find::Rule
File::Util       16.9/s               --             -47%
File::Find::Rule 31.9/s              89%               --

