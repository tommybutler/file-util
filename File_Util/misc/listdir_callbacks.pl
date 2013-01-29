#!/usr/bin/perl

use warnings;
use strict;
use 5.10.0;

use lib './lib';
use File::Util;

my $ftl = File::Util->new( { fatals_as_status => 1 } );

sub sayindent {
   my ( $indent, $text ) = @_;
   say( ( ' ' x ( $indent * 3 ) ) . $text );
}

sub dirs_callback
{
   my ( $dir, $subdirs, $depth ) = @_;

   sayindent( $depth,  qq(  SUBDIRS IN $dir) );
   sayindent( $depth,  "    - none" ) and return unless @$subdirs;
   sayindent( $depth, "    - $_" ) for @$subdirs;

   return;
};

sub files_callback
{
   my ( $dir, $files, $depth ) = @_;

   sayindent( $depth, qq(  FILES in $dir) );
   sayindent( $depth, "    - none\n" ) and return unless @$files;
   sayindent( $depth, "    - $_" ) for @$files;
   print "\n";

   return;
};

sub callback
{
   my ( $dir, $subdirs, $files, $depth ) = @_;

   $subdirs = scalar @$subdirs;
   $files   = scalar @$files;

   sayindent( $depth, '+' . ( '-' x 70 ) );
   sayindent( $depth, qq(| IN $dir - $subdirs sub-directories | $files files | $depth DEEP) );
   sayindent( $depth, '+' . ( '-' x 70 ) );
};

$ftl->list_dir(
   '.' => {
      d_callback  => \&dirs_callback,
      f_callback  => \&files_callback,
      callback    => \&callback,
      recurse     => 1,
   }
);

exit;
