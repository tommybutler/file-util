#!/usr/bin/perl

use warnings;
use strict;

use lib './lib';
use File::Util;

my $ftl = File::Util->new( { onfail => 'zero' } );

$ftl->list_dir(
   '.' => {
      d_callback  => \&dirs_callback,
      f_callback  => \&files_callback,
      callback    => \&callback,
      recurse     => 1,
   }
);

exit;

sub print_indent {
   my ( $indent, $text ) = @_;
   print( ( ' ' x ( $indent * 3 ) ) . $text . "\n" );
}

sub dirs_callback
{
   my ( $dir, $subdirs, $depth ) = @_;

   print_indent( $depth, qq(  SUBDIRS IN $dir) );
   print_indent( $depth, "    - none" ) and return unless @$subdirs;
   print_indent( $depth, "    - $_" ) for @$subdirs;

   return;
}

sub files_callback
{
   my ( $dir, $files, $depth ) = @_;

   print_indent( $depth, qq(  FILES in $dir) );
   print_indent( $depth, "    - none\n" ) and return unless @$files;
   print_indent( $depth, "    - $_" ) for @$files;
   print "\n";

   return;
}

sub callback
{
   my ( $dir, $subdirs, $files, $depth ) = @_;

   $subdirs = scalar @$subdirs;
   $files   = scalar @$files;

   print_indent( $depth, '+' . ( '-' x 70 ) );
   print_indent( $depth, qq(| IN $dir - $subdirs sub-directories | $files files | $depth DEEP) );
   print_indent( $depth, '+' . ( '-' x 70 ) );
}
