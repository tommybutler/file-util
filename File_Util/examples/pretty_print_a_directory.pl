# ABSTRACT: pretty print a directory, recursively

# set this to the name of the directory to pretty-print
my $treetrunk = '/tmp';

use strict;
use warnings;

use File::Util qw( NL );
my $indent = '';
my $ftl    = File::Util->new();
my @opts   = qw(
   --with-paths
   --sl-after-dirs
   --no-fsdots
   --files-as-ref
   --dirs-as-ref
);

my $filetree  = {};
my $treetrunk = '/tmp';
my( $subdirs, $sfiles ) = $ftl->list_dir( $treetrunk, @opts );

$filetree = [{
   $treetrunk => [ sort { uc $a cmp uc $b } @$subdirs, @$sfiles ]
}];

descend( $filetree->[0]{ $treetrunk }, scalar @$subdirs );

walk( @$filetree );

exit;

sub descend {

   my( $parent, $dirnum ) = @_;

   for ( my $i = 0; $i < $dirnum; ++$i ) {

      my $current = $parent->[ $i ];

      next unless -d $current;

      my( $subdirs, $sfiles ) = $ftl->list_dir( $current, @opts );

      map { $_ = $ftl->strip_path( $_ ) } @$sfiles;

      splice @$parent, $i, 1,
      { $current => [ sort { uc $a cmp uc $b } @$subdirs, @$sfiles ] };

      descend( $parent->[$i]{ $current }, scalar @$subdirs );
   }

   return $parent;
}

sub walk {

   my $dir = shift @_;

   foreach ( @{ [ %$dir ]->[1] } ) {

      my $mem = $_;

      if ( ref $mem eq 'HASH' ) {

         print $indent . $ftl->strip_path([ %$mem ]->[0]) . '/', NL;

         $indent .= ' ' x 3; # increase indent

         walk( $mem );

         $indent = substr( $indent, 3 ); # decrease indent

      } else { print $indent . $mem, NL }
   }
}

