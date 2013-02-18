#!/usr/bin/perl
use strict;
use warnings;

use lib '../lib';
use lib 'lib';

use File::Util;
use 5.10.0;

my $dir       = shift @ARGV || '/home/superman/nocloud';
my $max_depth = shift @ARGV || 4;

my $ftl = File::Util->new();

#say qq(Listing "$dir".  My max depth is $max_depth);

say for
   $ftl->list_dir
   (
      $dir =>
      {
         recurse     => 1,
         max_depth   => $max_depth,
         dirs_only   => 1,
         diag        => 1,
         #callback    => \&callback_depth_confirm,
      }
   );

exit;

sub callback_depth_confirm
{
   my ( $parent, $dirs, $files, $depth ) = @_;

   say qq(I'm in $parent, $depth levels deep!);

#   say for @$dirs;
#   say for @$files;
}

