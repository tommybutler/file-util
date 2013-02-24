#!/usr/bin/perl

use strict;
use warnings;

use Time::HiRes;
use Benchmark::Forking qw( :all );

use lib './lib';
use lib '../lib';

use File::Util;
use File::Find::Rule;

my $f = File::Util->new();

# some dir with several subdirs (and .pod files preferably)
my $dir = '.';

print "\nNON-RECURSIVE\n";
cmpthese
   10_000,
   {
      'File::Util'       => sub { $f->list_dir( $dir => { files_only => 1 } ) },
      'File::Find::Rule' => sub { File::Find::Rule->maxdepth(1)->file->in( $dir ) },
   };

print "\nNON-RECURSIVE WITH REGEXES\n";
cmpthese
   10_000,
   {
      'File::Util'       => sub { $f->list_dir( $dir => { files_only => 1, files_match => qr/\.pod$/ } ) },
      'File::Find::Rule' => sub { File::Find::Rule->maxdepth(1)->file->name( qr/\.pod$/ )->in( $dir ) },
   };

print "\nRECURSIVE\n";
cmpthese
   400,
   {
      'File::Util'       => sub { $f->list_dir( $dir => { recurse => 1, files_only => 1 } ) },
      'File::Find::Rule' => sub { File::Find::Rule->file->in( $dir ) },
   };

print "\nRECURSIVE WITH REGEXES\n";
cmpthese
   400,
   {
      'File::Util'       => sub { $f->list_dir( $dir => { recurse => 1, files_only => 1, files_match => qr/\.pod$/ } ) },
      'File::Find::Rule' => sub { File::Find::Rule->file->name( qr/\.pod$/ )->in( $dir ) },
   };

__END__

----------------------------------------------------------------------
Sat Feb 23 21:47:33 CST 2013
----------------------------------------------------------------------

NON-RECURSIVE
                    Rate File::Find::Rule       File::Util
File::Find::Rule  2611/s               --             -80%
File::Util       12987/s             397%               --

NON-RECURSIVE WITH REGEXES
                   Rate File::Find::Rule       File::Util
File::Find::Rule 2551/s               --             -73%
File::Util       9524/s             273%               --

RECURSIVE
                  Rate File::Find::Rule       File::Util
File::Find::Rule 211/s               --             -29%
File::Util       299/s              42%               --

RECURSIVE WITH REGEXES
                  Rate File::Find::Rule       File::Util
File::Find::Rule 215/s               --             -25%
File::Util       286/s              33%               --


----------------------------------------------------------------------
Thu Feb 21 21:48:07 CST 2013
----------------------------------------------------------------------

NON-RECURSIVE
                    Rate File::Find::Rule       File::Util
File::Find::Rule  4065/s               --             -79%
File::Util       19231/s             373%               --

NON-RECURSIVE WITH REGEXES
                    Rate File::Find::Rule       File::Util
File::Find::Rule  3704/s               --             -66%
File::Util       10753/s             190%               --

RECURSIVE
                   Rate File::Find::Rule       File::Util
File::Find::Rule 23.9/s               --             -13%
File::Util       27.5/s              15%               --

RECURSIVE WITH REGEXES
                   Rate       File::Util File::Find::Rule
File::Util       26.1/s               --              -0%
File::Find::Rule 26.2/s               0%               --


----------------------------------------------------------------------
Thu Feb 21 15:43:42 CST 2013
----------------------------------------------------------------------
NON-RECURSIVE
                    Rate File::Find::Rule       File::Util
File::Find::Rule  4132/s               --             -77%
File::Util       17857/s             332%               --

NON-RECURSIVE WITH REGEXES
                    Rate File::Find::Rule       File::Util
File::Find::Rule  3425/s               --             -68%
File::Util       10870/s             217%               --

RECURSIVE
                   Rate       File::Util File::Find::Rule
File::Util       21.9/s               --             -18%
File::Find::Rule 26.7/s              22%               --

RECURSIVE WITH REGEXES
                   Rate       File::Util File::Find::Rule
File::Util       23.4/s               --             -22%
File::Find::Rule 30.0/s              28%               --


----------------------------------------------------------------------
Wed Feb 20 ??:??:?? CST 2013
----------------------------------------------------------------------
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

