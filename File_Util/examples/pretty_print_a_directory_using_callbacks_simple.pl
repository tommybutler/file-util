# ABSTRACT: pretty print a directory, recursively, using callbacks

# set this to the name of the directory to pretty-print
my $treetrunk = '.';

use warnings;
use strict;

use lib './lib';
use File::Util qw( NL );

my $ftl = File::Util->new( { onfail => 'zero' } );
my @tree;

$ftl->list_dir( $treetrunk => { callback => \&callback, recurse => 1 } );

print for sort { uc ltrim( $a ) cmp uc ltrim( $b ) } @tree;

exit;

sub callback
{
   my ( $dir, $subdirs, $files, $depth ) = @_;

   stash( $depth, $_ ) for @$subdirs;
   stash( $depth, $_ ) for @$files;

   return;
}

sub stash
{
   my ( $indent, $text ) = @_;
   push( @tree, ( ' ' x ( $indent * 3 ) ) . $text . NL );
}

sub ltrim { my $trim = shift @_; $trim =~ s/^\s+//; $trim }

