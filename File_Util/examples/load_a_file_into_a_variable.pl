#!/usr/bin/perl

use strict;
use warnings;
use File::Util;

my $ftl = File::Util->new();

my $file = 'example.txt'; # in this example, this file must already exist
my $content = $ftl->load_file( $file );

print $content;

exit;
