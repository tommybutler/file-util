#!/usr/bin/perl

# perl -d:NYTProf misc/bench_listdir.pl

use strict;
use warnings;

use lib './lib';
use lib '../lib';

use File::Util;

my $f   = File::Util->new();
my $dir = '/home/superman/nocloud/';

$f->list_dir( $dir => { recurse => 1, files_only => 1, files_match => qr/\.pod$/ } );

__END__

