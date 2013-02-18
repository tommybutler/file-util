#!/usr/bin/perl

use strict;
use warnings;

use Time::HiRes;
use Benchmark::Forking qw( :all );

use lib './lib';
use lib '../lib';

cmpthese
   5_000_000,
   {
      'File::Util'       => sub { eval { require File::Util } },
      'File::Spec'       => sub { eval { require File::Spec } },
      'Path::Tiny'       => sub { eval { require Path::Tiny } },
      'Path::Class'      => sub { eval { require Path::Class } },
      'File::Slurp'      => sub { eval { require File::Slurp } },
      'File::Find'       => sub { eval { require File::Find } },
      'File::Find::Rule' => sub { eval { require File::Find::Rule } },
      'Moose'            => sub { eval { require Moose } },
   };

__END__

                      Rate Moose File::Find::Rule Path::Tiny Path::Class File::Slurp File::Spec File::Find File::Util
Moose            5102041/s    --              -2%        -3%         -7%        -10%       -11%       -11%       -13%
File::Find::Rule 5208333/s    2%               --        -1%         -5%         -8%        -9%        -9%       -11%
Path::Tiny       5263158/s    3%               1%         --         -4%         -7%        -8%        -8%       -11%
Path::Class      5494505/s    8%               5%         4%          --         -3%        -4%        -4%        -7%
File::Slurp      5681818/s   11%               9%         8%          3%          --        -1%        -1%        -3%
File::Spec       5747126/s   13%              10%         9%          5%          1%         --         0%        -2%
File::Find       5747126/s   13%              10%         9%          5%          1%         0%         --        -2%
File::Util       5882353/s   15%              13%        12%          7%          4%         2%         2%         --
