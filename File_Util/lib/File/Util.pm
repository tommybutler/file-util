use 5.006;
use strict;
use warnings;

use lib 'lib';

package File::Util;

use File::Util::Definitions qw( :all );
use File::Util::Interface::Modern qw( :all );

use vars qw( @ISA  @EXPORT_OK  %EXPORT_TAGS );

use Exporter;

$AUTHORITY  = 'cpan:TOMMY';
@ISA        = qw( Exporter );

# some of the symbols below come from File::Util::Definitions
@EXPORT_OK  = qw(
   NL     can_flock   ebcdic       existent      needs_binmode
   SL     strip_path  can_read     can_write     valid_filename
   OS     bitmask     return_path  file_type     escape_filename
   isbin  created     last_access  last_changed  last_modified
   size   split_path  atomize_path
);

%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

# default setting is "1" for now, until test suite updated and documentation as well
our $WANT_DIAGNOSTICS = 1;

# --------------------------------------------------------
# Constructor
# --------------------------------------------------------
sub new {
   my $this = { };

   bless $this, shift @_;

   my $in = $this->_parse_in( @_ ) || { };

   $this->{opts} = $in || { };

   # let constructor argument override globals, but set
   # constructor opts to global values if they have not
   # overridden them...

   $USE_FLOCK  = $in->{use_flock}
      if exists  $in->{use_flock}
      && defined $in->{use_flock};

      $this->{opts}->{use_flock} = $USE_FLOCK;

   $WANT_DIAGNOSTICS = $in->{diag}
      if exists  $in->{diag}
      && defined $in->{diag};

      $this->{opts}->{diag} = $WANT_DIAGNOSTICS;

   $READLIMIT  = $in->{readlimit}
      if exists  $in->{readlimit}
      && defined $in->{readlimit}
      && $in->{readlimit} !~ /\D/;

      $this->{opts}->{readlimit} = $READLIMIT;

   $MAXDIVES   = $in->{max_dives}
      if exists  $in->{max_dives}
      && defined $in->{max_dives}
      && $in->{max_dives} !~ /\D/;

      $this->{opts}->{max_dives} = $MAXDIVES;

   return $this;
}


# --------------------------------------------------------
# File::Util::import()
# --------------------------------------------------------
sub import {

   my ( $class, @wanted_symbols ) = @_;

   ++$WANT_DIAGNOSTICS if grep { /(?<!!):diag/ } @wanted_symbols;

   $class->export_to_level( 1, @_ );
}


# --------------------------------------------------------
# File::Util::list_dir()
# --------------------------------------------------------
sub list_dir {
   my $this = shift @_;
   my $opts = $this->_remove_opts( \@_ );
   my $dir  = shift @_ || '.';
   my $path = $dir;
   my $maxd = $opts->{max_dives} || $MAXDIVES;
   my ( @dirs, @files, @items );

   # "." and ".." make no sense (and cause infinite loops) when recursing...
   $opts->{no_fsdots} = 1 if $opts->{recurse}; # ...so skip them

   # break off immediately to helper function if asked to make a ref-tree
   return $this->_as_tree( $dir => $opts ) if $opts->{ as_tree };

   my $recursing = 0; # flag to dynamicall indicate whether or not this
                      # method is being used recursively for this call

# INPUT VALIDATION

   return $this->_throw(
      'no input' => {
         meth    => 'list_dir',
         missing => 'a directory name',
         opts    => $opts,
      }
   ) unless length $dir;

   return $this->_throw( 'no such file' => { filename => $dir } )
      unless -e $dir;

   # whack off any trailing directory separator, except for root directories
   # -account for both posix filesystem AND micro$oft path notation
   unless ( length $dir == 1 || $dir =~ /^$WINROOT$/o ) {

      # removes one or more dirsep at the end of $dir
      $dir =~ s/(?:$DIRSPLIT){1,}$//o;
   }

   return $this->_throw (
      'called opendir on a file' => {
         filename => $dir,
         opts     => $opts,
      }
   ) unless -d $dir;

# RUNAWAY RECURSION PREVENTION

   # this directory recursion method keeps track of dives based on the parent
   # directory of $dir, rather than on $dir itself so that multiple
   # subdirectories within the same parent directory don't improperly increment
   # the number of dives made
   if ( $opts->{recursing} ) {

      my $pdir = $dir; $pdir =~ s/(^.*)$DIRSPLIT.*/$1/;

      $this->{traversed}{ $pdir } = $pdir;
   }
   else { $this->{traversed} = { } }

   # enforce maximum subdirectory dives, unless $MAXDIVES is equal to zero
   if ( $MAXDIVES != 0 && ( scalar keys %{ $this->{traversed} } >= $maxd ) ) {

      return $this->_throw(
         'maxdives exceeded' => {
            meth     => 'list_dir',
            maxdives => $maxd,
            opts     => $opts,
         }
      )
   }

   $recursing = 1 if $opts->{follow} || $opts->{recurse};

   opendir my $dir_fh, $dir
      or return $this->_throw
         (
            'bad opendir' => {
               dirname    => $dir,
               exception  => $!,
               opts       => $opts,
            }
         );

   # read from beginning of the directory (doesn't seem necessary on any
   # platforms I've run code on, but just in case...)
   rewinddir $dir_fh;

# LEGACY_MATCHING

   # this form of matching is deprecated and is not robust.  backward compat
   # is preserved here, but it will soon no longer even be mentioned in the
   # documentation, becoming useful only to the legacy code that relies on it

   # primitive pattern matching at top level only, applied to both files & dirs
   @files = defined $opts->{pattern}
      ? grep /$opts->{pattern}/, readdir $dir_fh
      : readdir $dir_fh;

   # primitive pattern matching applied recursively to only files; if it were
   # applied to both files AND dirs, recursion would often break unexpectedly
   # for users unaware that they couldn't recurse into dirs that didn't match
   # the pattern they probably intended only for files
   @files = defined $opts->{rpattern}
      ? grep { -d $path . SL . $_ || /$opts->{rpattern}/ } @files
      : @files;

   closedir $dir_fh
      or return $this->_throw(
         'close dir'  => {
            dir       => $dir,
            exception => $!,
            opts      => $opts,
         }
      );

   # get rid of "." and ".." if they are unwanted
   @files = grep { !/$FSDOTS/o } @files if $opts->{no_fsdots};

# ADVANCED MATCHING

   @files = _list_dir_matching( $opts, $path, \@files );

# SEPARATION OF DIRS FROM FILES

   # prepend full path information to each file name if paths were
   # requested, or if we are recursing.  Then separate the directories
   # and files off into @dirs and @itmes, respectively
   for my $file ( @files ) {

      my $listing = ( $opts->{with_paths} || $recursing )
         ? $path . SL . $file
         : $file;

      if ( -d $path . SL . $file ) {

         push @dirs, $listing
      }
      else { push @items, $listing }
   }

# CALLBACKS (HIGHER ORDER FUNCTIONS)

   # here below is where we invoke the callbacks on dirs, files, or both.

   if ( my $cb = $opts->{callback} ) {

      $this->throw( qq(callback "$cb" not a coderef) )
         unless ref $cb eq 'CODE';

      $cb->( $dir, \@dirs, \@items, scalar split_path( $dir ) - 1 );
   }

   if ( my $cb = $opts->{d_callback} ) {

      $this->throw( qq(d_callback "$cb" not a coderef) )
         unless ref $cb eq 'CODE';

      $cb->( $dir, \@dirs, scalar split_path( $dir ) - 1 );
   }

   if ( my $cb = $opts->{f_callback} ) {

      $this->throw( qq(f_callback "$cb" not a coderef) )
         unless ref $cb eq 'CODE';

      $cb->( $dir, \@items, scalar split_path( $dir ) - 1 );
   }

# RECURSION

   if ( $recursing ) {

      @dirs = grep { strip_path( $_ ) !~ /$FSDOTS/ } @dirs;

      # recurse into all subdirs
      for my $subdir ( @dirs ) {

         # certain opts need to be defined, overridden, added, or removed
         # completely before recursing.  That's why we redefine everything
         # here below, eliminating potential user-error where incompatible
         # options would otherwise break recursion and/or cause confusion

         my $recurse_opts = {
            as_ref         => 1,
            with_paths     => 1,
            recursing      => 1,
            no_fsdots      => 1,
            max_dives      => $maxd,
            rpattern       => $opts->{rpattern},
            files_match    => $opts->{files_match},
            dirs_match     => $opts->{dirs_match},
            parent_matches => $opts->{parent_matches},
            path_matches   => $opts->{path_matches},
            callback       => $opts->{callback},
            d_callback     => $opts->{d_callback},
            f_callback     => $opts->{f_callback},
         };

         my ( $dirs_ref, $files_ref ) =
            $this->list_dir( $subdir, $recurse_opts );

         push @dirs,  @$dirs_ref;
         push @items, @$files_ref;
      }
   }

# FINAL PREPARATIONS before returning results

   if (
        !$opts->{recursing} &&
      (
         $opts->{path_matches} ||
         $opts->{parent_matches}
      )
   ) {
      @dirs = _list_dir_lastround_dirmatch( $opts, \@dirs );
   }

   # cosmetic formatting for directories/
   if ( $opts->{sl_after_dirs} ) {

      # append directory separator to everything but the "dots"
      $_ .= SL for grep { !/$FSDOTS/o } @dirs;
   }

   my $return_dirs = []; my $return_files = [];

   # sorting
   if ( $opts->{ignore_case} ) {

      $return_dirs  = [ sort { uc $a cmp uc $b } @dirs  ];
      $return_files = [ sort { uc $a cmp uc $b } @items ];
   }
   else {

      $return_dirs  = [ sort { $a cmp $b } @dirs  ];
      $return_files = [ sort { $a cmp $b } @items ];
   }

# RETURN based on selected opts

   return scalar @$return_dirs
      if $opts->{dirs_only} && $opts->{count_only};

   return scalar @$return_files
      if $opts->{files_only} && $opts->{count_only};

   return scalar @$return_dirs + scalar @$return_files
      if $opts->{count_only};

   return $return_dirs, $return_files
      if $opts->{as_ref};

   $return_dirs  = [ $return_dirs  ] if $opts->{dirs_as_ref};
   $return_files = [ $return_files ] if $opts->{files_as_ref};

   return @$return_dirs  if $opts->{dirs_only};
   return @$return_files if $opts->{files_only};

   return @$return_dirs, @$return_files;
}


# --------------------------------------------------------
# File::Util::_list_dir_matching()
# --------------------------------------------------------
sub _list_dir_matching {
   my ( $opts, $path, $files ) = @_;

   my @qualified_files = map { $path . SL . $_ } splice @$files, 0;
   # can't keep multiple huge lists of files --- ^^^^^^

   my @qualified_dirs  = grep { -d $_ } @qualified_files;

   my %dirs_only; @dirs_only{ @qualified_dirs } = @qualified_dirs;

   @qualified_files = grep { !exists $dirs_only{ $_ } } @qualified_files;

   my @files_match = map { strip_path( $_ ) } @qualified_files;
   my @dirs_match  = map { strip_path( $_ ) } @qualified_dirs;

   # memory management
   undef %dirs_only;
   undef @qualified_files;
   undef @qualified_dirs;

# COLLECT PATTERN(S) TO BE APPLIED

   my @files_match_or;
   my @files_match_and  = _gather_and_patterns( $opts->{files_match} );
      @files_match_or   = _gather_or_patterns( $opts->{files_match} )
         unless scalar @files_match_and;

   my @dirs_match_or;
   my @dirs_match_and   = _gather_and_patterns( $opts->{dirs_match} );
      @dirs_match_or    = _gather_or_patterns( $opts->{dirs_match} )
         unless scalar @dirs_match_and;

   my @parent_matches_or;
   my @parent_matches_and = _gather_and_patterns( $opts->{parent_matches} );
      @parent_matches_or  = _gather_or_patterns( $opts->{parent_matches} )
         unless scalar @parent_matches_and;

   my @path_matches_or;
   my @path_matches_and   = _gather_and_patterns( $opts->{path_matches} );
      @path_matches_or    = _gather_or_patterns( $opts->{path_matches} )
         unless scalar @path_matches_and;

# FILE MATCHING

   for my $pattern ( @files_match_and ) {

      @files_match = grep { /$pattern/ } @files_match;
   }

   @files_match = _match_and( \@files_match_and, \@files_match )
      if scalar @files_match_and;

   @files_match = _match_or( \@files_match_or, \@files_match )
      if scalar @files_match_or;

# DIRECTORY MATCHING

   @dirs_match = _match_and( \@dirs_match_and, \@dirs_match )
      if scalar @dirs_match_and;

   @dirs_match = _match_or( \@dirs_match_or, \@dirs_match )
      if scalar @dirs_match_or;

# FILE &'ed DIRECTORY MATCHING

   if ( $opts->{files_match} && $opts->{dirs_match} ) {

      @files_match = ( )
         unless _match_and( \@dirs_match_and, [ strip_path( $path ) ] );
   }

# MATCHING FILES BY PARENT DIR

   if ( $opts->{parent_matches} ) {

      if ( @parent_matches_and ) {

         @files_match = ( )
            unless _match_and( \@parent_matches_and, [ strip_path( $path ) ] );
      }
      elsif ( @parent_matches_or ) {

         @files_match = ( )
            unless _match_or( \@parent_matches_or, [ strip_path( $path ) ] );
      }
   }

# MATCHING FILES BY PATH

   if ( $opts->{path_matches} ) {

      if ( @path_matches_and ) {

         @files_match = ( )
            unless _match_and( \@path_matches_and, [ $path ] );
      }
      elsif ( @path_matches_or ) {

         @files_match = ( )
            unless _match_or( \@path_matches_or, [ $path ] );
      }
   }

   return ( @dirs_match, @files_match );
}


# --------------------------------------------------------
# File::Util::_list_dir_lastround_dirmatch()
# --------------------------------------------------------
sub _list_dir_lastround_dirmatch {
   my ( $opts, $dirs ) = @_;

   my @return_dirs;

   my @qualified_dirs = splice @$dirs, 0;
   # can't keep multiple ^^^^^ potentially huge lists of files in RAM

   my @parent_matches_or;
   my @parent_matches_and = _gather_and_patterns( $opts->{parent_matches} );
      @parent_matches_or  = _gather_or_patterns( $opts->{parent_matches} )
         unless scalar @parent_matches_and;

   my @path_matches_or;
   my @path_matches_and   = _gather_and_patterns( $opts->{path_matches} );
      @path_matches_or    = _gather_or_patterns( $opts->{path_matches} )
         unless scalar @path_matches_and;

# LAST ROUND MATCHING DIRS BY PARENT DIR

   if ( $opts->{parent_matches} ) {

      my %return_dirs;

      if ( @parent_matches_and ) {

         for my $qfd_dir ( @qualified_dirs ) {

            my ( $root, $in_path ) = atomize_path( $qfd_dir );

            $in_path = $root . $in_path if $root;

            $return_dirs{ $in_path } = $in_path
            if _match_and( \@parent_matches_and, [ strip_path( $in_path ) ] );
         }
      }
      elsif ( @parent_matches_or ) {

         for my $qfd_dir ( @qualified_dirs ) {

            my ( $root, $in_path ) = atomize_path( $qfd_dir );

            $in_path = $root . $in_path if $root;

            $return_dirs{ $in_path } = $in_path
            if _match_or( \@parent_matches_or, [ strip_path( $in_path ) ] );
         }
      }

      push @return_dirs, keys %return_dirs;
   }

# LAST ROUND MATCHING DIRS BY PATH

   if ( $opts->{path_matches} ) {

      my %return_dirs;

      if ( @path_matches_and ) {

         for my $qfd_dir ( @qualified_dirs ) {

            my ( $root, $in_path ) = atomize_path( $qfd_dir );

            $in_path = $root . $in_path if $root;

            $return_dirs{ $in_path } = $in_path
               if _match_and( \@path_matches_and, [ $in_path ] );

            $return_dirs{ $qfd_dir } = $qfd_dir
               if _match_and( \@path_matches_and, [ $qfd_dir ] );
         }
      }
      elsif ( @path_matches_or ) {

         for my $qfd_dir ( @qualified_dirs ) {

            my ( $root, $in_path ) = atomize_path( $qfd_dir );

            $in_path = $root . $in_path if $root;

            $return_dirs{ $in_path } = $in_path
               if _match_or( \@path_matches_or, [ $in_path ] );

            $return_dirs{ $qfd_dir } = $qfd_dir
               if _match_or( \@path_matches_or, [ $qfd_dir ] );
         }
      }

      push @return_dirs, keys %return_dirs;
   }

   return @return_dirs;
}


# --------------------------------------------------------
# File::Util::_gather_and_patterns()
# --------------------------------------------------------
sub _gather_and_patterns {

   my $pattern_ref = shift @_;

   return
      defined $pattern_ref &&
      ref $pattern_ref eq 'HASH' &&
      defined $pattern_ref->{and} &&
      ref $pattern_ref->{and} eq 'ARRAY'
         ? @{ $pattern_ref->{and} }
         : defined $pattern_ref &&
           ref $pattern_ref eq 'Regexp'
            ? ( $pattern_ref )
            : ( );
}


# --------------------------------------------------------
# File::Util::_gather_or_patterns()
# --------------------------------------------------------
sub _gather_or_patterns {

   my $pattern_ref = shift @_;

   return
      defined $pattern_ref &&
      ref $pattern_ref eq 'HASH' &&
      defined $pattern_ref->{or} &&
      ref $pattern_ref->{or} eq 'ARRAY'
         ? @{ $pattern_ref->{or} }
         : ( );
}


# --------------------------------------------------------
# File::Util::_match_and()
# --------------------------------------------------------
sub _match_and {

   my ( $patterns, $items ) = @_;

   for my $pattern ( @$patterns ) {

      @$items = grep { /$pattern/ } @$items;
   }

   return @$items;
}


# --------------------------------------------------------
# File::Util::_match_or()
# --------------------------------------------------------
sub _match_or {

   my ( $patterns, $items ) = @_;

   my $or_pattern;

   for my $pattern ( @$patterns ) {

      $or_pattern = $or_pattern
         ? qr/$pattern|$or_pattern/
         : $pattern;
   }

   @$items = grep { /$or_pattern/ } @$items;

   return @$items;
}


# --------------------------------------------------------
# File::Util::_as_tree()
# --------------------------------------------------------
sub _as_tree {
   my $this = shift @_;
   my $opts = $this->_remove_opts( \@_ );
   my $dir  = shift @_ || '.';
   my $tree = {};

   my $treeify = sub
   {
      my ( $dirname, $subdirs, $files ) = @_;

      # find root of tree (if path was absolute)
      my ( $root, $branch, $leaf ) = atomize_path( $dirname );

      my @path_dirs = split /$DIRSPLIT/o, $branch;

      # find place in tree
      my @lineage = ( @path_dirs, $leaf );

      unshift @lineage, $root if $root;

      my $ancestory = $tree;

      # recursively create hashref tree

      for ( my $i = 0; $i < @lineage; $i++ )
      {
         my $self = $lineage[ $i ];

         my $parent = $i > 0 ? $i - 1 : undef;

         if ( defined $parent )
         {
            my @predecessors = @lineage[ 0 .. $parent ];

            # for abs paths on *nix
            shift @predecessors if
               @predecessors > 1 &&
               $predecessors[0] eq SL;

            $parent = join SL, @predecessors;

            $parent = $root . $parent if $root && $parent ne $root;
         }

         $ancestory->{ $self } ||= { };

         unless (
            exists  $opts->{dirmeta} &&
            defined $opts->{dirmeta} &&
            $opts->{dirmeta} == 0
         ) {
            $ancestory->{ $self }{ _DIR_PARENT_ } = $parent;

            $ancestory->{ $self }{ _DIR_SELF_ }   =
               !defined $parent
                  ? $self
                  : $parent eq $root
                     ? $parent . $self
                     : $parent . SL . $self;
         }

         $ancestory = $ancestory->{ $self };
      }

      # the next two loops populate the tree

      my $parent = $ancestory;

      for my $subdir ( @$subdirs )
      {
         $parent->{ strip_path( $subdir ) } ||= { };
      }

      for my $file ( @$files )
      {
         $parent->{ strip_path( $file ) } = $file;
      }
   };

   $this->list_dir(
      $dir => {
         callback       => $treeify,
         recurse        => $opts->{recurse},
         files_match    => $opts->{files_match},
         dirs_match     => $opts->{dirs_match},
         parent_matches => $opts->{parent_matches},
         path_matches   => $opts->{path_matches},
         pattern        => $opts->{pattern},
         rpattern       => $opts->{rpattern},
      }
   );

   return $tree;
}


# --------------------------------------------------------
# File::Util::_dropdots()
# --------------------------------------------------------
sub _dropdots {
   my $this     = shift @_;
   my $opts     = $this->_remove_opts( \@_ );
   my @copy     = @_;
   my @out      = ();
   my @dots     = ();
   my $gottadot = 0;

   while ( @copy ) {

      if ( $gottadot == 2 ) { push @out, @copy and last }

      my $dir_item = shift @copy;

      if ( $dir_item =~ /$FSDOTS/ ) {

         ++$gottadot;

         push @dots, $dir_item;

         next;
      }

      push @out, $dir_item;
   }

   return( \@dots, @out ) if $opts->{save_dots};

   return @out;
}


# --------------------------------------------------------
# File::Util::load_file()
# --------------------------------------------------------
sub load_file {
   my $this       = shift @_;
   my $opts       = $this->_remove_opts( \@_ );
   my $in         = $this->_names_values( @_ );
   my @dirs       = ();
   my $blocksize  = 1024; # 1.24 kb
   my $fh_passed  = 0;
   my $fh;

   my ( $file, $root, $path, $clean_name, $content, $mode  ) =
      ( '',    '',    '',    '',          '',       'read' );

   my $readlimit = $opts->{readlimit} || $this->{opts}{readlimit} || $READLIMIT;

   # support old-school "FH" option, *and* the new, more sensible "file_handle"
   $opts->{FH} = $opts->{file_handle}
      if defined $opts->{file_handle} &&
         ref $opts->{file_handle} eq 'GLOB';

   if ( scalar @_ == 1 ) {

      $file = shift @_ || '';

      return $this->_throw(
         'no input',
         {
            meth    => 'load_file',
            missing => 'a file name or file handle reference',
            opts    => $opts,
         }
      ) unless length $file;

      ( $root, $path, $file ) = atomize_path( $file );

      @dirs = split /$DIRSPLIT/, $path;

      unshift @dirs, $root if $root;

      # cleanup file name - if path is relative, normalize it
      #    - /foo/bar/baz.txt stays as /foo/bar/baz.txt
      #    - foo/bar/baz.txt  becomes ./foo/bar/baz.txt
      #    - baz.txt          stays as baz.txt
      if ( !length $root && !length $path ) {

         $path = '.' . SL;
      }
      else { # otherwise path normalized at end

         $path .= SL;
      }

      # final clean filename assembled
      $clean_name = $root . $path . $file;
   }
   else {

      # did we get a filehandle?
      if ( ref $in->{FH} eq 'GLOB' ) {

         $fh_passed = 1;
      }
      else {

         return $this->_throw(
            'no input',
            {
               meth    => 'load_file',
               missing => 'a file name or file handle reference',
               opts    => $opts,
            }
         );
      }
   }

   if ( $fh_passed ) {

      my $buffer     = 0;
      my $bytes_read = 0;
      $fh = $opts->{FH};

      while ( <$fh> ) {

         if ( $buffer < $readlimit ) {

            $bytes_read = read( $fh, $content, $blocksize );

            $buffer += $bytes_read;
         }
         else {

            return $this->_throw(
               'readlimit exceeded',
               {
                  filename => '<filehandle>',
                  size     => qq{[truncated at $bytes_read]},
                  opts     => $opts,
               }
            );
         }
      }

      # return an array of all lines in the file if the call to this method/
      # subroutine asked for an array eg- my @file = load_file('file');
      # otherwise, return a scalar value containing all of the file's content
      return split /$NL|\r|\n/o, $content
         if $opts->{as_list};

      return $content;
   }

   # if the file doesn't exist, send back an error
   return $this->_throw(
      'no such file',
      {
         filename => $clean_name,
         opts     => $opts,
      }
   ) unless -e $clean_name;

   # it's good to know beforehand whether or not we have permission to open
   # and read from this file allowing us to handle such an exception before
   # it handles us.

   # first check the readability of the file's housing dir
   return $this->_throw(
      'cant dread',
      {
         filename => $clean_name,
         dirname  => $root . $path,
         opts     => $opts,
      }
   ) unless -r $root . $path;

   # now check the readability of the file itself
   return $this->_throw(
      'cant fread',
      {
         filename => $clean_name,
         dirname  => $root . $path,
         opts     => $opts,
      }
   ) unless -r $clean_name;

   # if the file is a directory it will not be opened
   return $this->_throw(
      'called open on a dir',
      {
         filename => $clean_name,
         opts     => $opts,
      }
   ) if -d $clean_name;

   my $fsize = -s $clean_name;

   return $this->_throw(
      'readlimit exceeded',
      {
         filename => $clean_name,
         size     => $fsize,
         opts     => $opts,
      }
   ) if $fsize > $READLIMIT;

   # localize the global output record separator so we can slurp it all
   # in one quick read.  We fail if the filesize exceeds our limit.
   local $/;

   # open the file for reading (note the '<' syntax there) or fail with a
   # error message if our attempt to open the file was unsuccessful
   my $cmd = '<' . $clean_name;

   # lock file before I/O on platforms that support it
   if (
      $$opts{no_lock}        ||
      $$this{opts}{no_lock}  ||
      !$this->use_flock()
   ) {

      # if you use the 'no_lock' option you are probably inefficient
      open $fh, $cmd or                            ## no critic
         return $this->_throw(                     ## use critic
            'bad open',
            {
               filename  => $clean_name,
               mode      => $mode,
               exception => $!,
               cmd       => $cmd,
               opts      => $opts,
            }
         );
   }
   else {
      open $fh, $cmd or                            ## no critic
         return $this->_throw(                     ## use critic
            'bad open',
            {
               filename  => $clean_name,
               mode      => $mode,
               exception => $!,
               cmd       => $cmd,
               opts      => $opts,
            }
         );

      $this->_seize( $clean_name, $fh );
   }

   # call binmode on binary files for portability accross platforms such
   # as MS flavor OS family

   CORE::binmode( $fh ) if -B $clean_name;

   # assign the content of the file to this lexically scoped scalar variable
   # (memory for *that* variable will be freed when execution leaves this
   # method / sub

   $content = <$fh>;

   if ( $$opts{no_lock} || $$this{opts}{no_lock} ) {

      # if execution gets here, you used the 'no_lock' option, and you
      # are probably inefficient

      close $fh or return $this->_throw(
         'bad close',
         {
            filename  => $clean_name,
            mode      => $mode,
            exception => $!,
            opts      => $opts,
         }
      );
   }
   else {
      # release shadow-ed locks on the file
      $this->_release( $fh );

      close $fh or return $this->_throw(
         'bad close',
         {
            filename  => $clean_name,
            mode      => $mode,
            exception => $!,
            opts      => $opts,
         }
      );
   }

   # return an array of all lines in the file if the call to this method/
   # subroutine asked for an array eg- my @file = load_file('file');
   # otherwise, return a scalar value containing all of the file's content
   return split /$NL|\r|\n/o, $content
      if $opts->{as_lines};

   return $content;
}


# --------------------------------------------------------
# File::Util::write_file()
# --------------------------------------------------------
sub write_file {
   my $this     = shift @_;
   my $in       = _parse_in( @_ );
   my $content  = '';
   my $raw_name = '';
   my $file     = '';
   my $mode     = $in->{mode}     || 'write';
   my $bitmask  = $in->{bitmask}  || oct 777;
   my $write_fh; # will be the lexical file handle local to this block
   my ( $root, $path, $clean_name, @dirs ) =
      ( '',    '',    '',          ()    );

   # get name of file when passed in as a name/value pair...

   $file =
      exists  $in->{filename} &&
      defined $in->{filename} &&
      length  $in->{filename}
         ? $in->{filename}
         : exists  $in->{file} &&
           defined $in->{file} &&
           length  $in->{file}
            ? $in->{file}
            : '';

   # ...or fall back to support of two-argument form of invocation

   my $maybe_file    = shift @_; $maybe_file    = '' if !defined $maybe_file;
   my $maybe_content = shift @_; $maybe_content = '' if !defined $maybe_content;

   $file    = $maybe_file if !ref $maybe_file && $file eq '';
   $content =
      !ref $maybe_content &&
      !exists $in->{content}
         ? $maybe_content
         : $in->{content};

   $raw_name = $file; # preserve original filename input before line below:

   ( $root, $path, $file ) = atomize_path( $file );

   $mode = 'trunc' if $mode eq 'truncate';
   $content = '' if $mode eq 'trunc';

   # if the call to this method didn't include a filename to which the caller
   # wants us to write, then complain about it
   return $this->_throw(
      'no input' => {
         meth    => 'write_file',
         missing => 'a file name to create, write, or append',
         opts    => $in,
      }
   ) unless length $file;

   # if prospective filename contains 2+ dir separators in sequence then
   # this is a syntax error we need to whine about
   {
      my $try_filename = $raw_name;

      $try_filename =~ s/$WINROOT//; # windows abs paths would throw this off

      return $this->_throw(
         'bad chars' => {
            string   => $raw_name,
            purpose  => 'the name of a file or directory',
            opts     => $in,
         }
      ) if $try_filename =~ /(?:$DIRSPLIT){2,}/;
   }

   # if the call to this method didn't include any data which the caller
   # wants us to write or append to the file, then complain about it
   return $this->_throw(
      'no input' => {
         meth    => 'write_file',
         missing => 'the content you want to write or append',
         opts    => $in,
      }
   ) if (
      length $content == 0
         &&
      $mode ne 'trunc'
         &&
      !$EMPTY_WRITES_OK
         &&
      !$in->{empty_writes_OK}
         &&
      !$in->{empty_writes_ok}
   );

   # check if file already exists in the form of a directory
   return $this->_throw(
      'cant write_file on a dir' => {
         filename => $raw_name,
         opts     => $in,
      }
   ) if -d $raw_name;

   # determine existance of the file path, make directory(ies) for the
   # path if the full directory path doesn't exist
   @dirs = split /$DIRSPLIT/, $path;

   # if prospective file name has illegal chars then complain
   foreach ( @dirs ) {

      return $this->_throw(
         'bad chars' => {
            string   => $_,
            purpose  => 'the name of a file or directory',
            opts     => $in,
         }
      ) if !$this->valid_filename( $_ );
   }

   # do this AFTER the above check!!
   unshift @dirs, $root if $root;

   # make sure that open mode is a valid mode
   unless ( $mode eq 'write' || $mode eq 'append' || $mode eq 'trunc' ) {

      return $this->_throw(
         'bad openmode popen' => {
            meth     => 'write_file',
            filename => $raw_name,
            badmode  => $mode,
            opts     => $in,
         }
      )
   }

   # cleanup file name - if path is relative, normalize it
   #    - /foo/bar/baz.txt stays as /foo/bar/baz.txt
   #    - foo/bar/baz.txt  becomes ./foo/bar/baz.txt
   #    - baz.txt          stays as baz.txt
   if ( !length $root && !length $path ) {

      $path = '.' . SL;
   }
   else { # otherwise path normalized at end

      $path .= SL;
   }

   # final clean filename assembled
   $clean_name = $root . $path . $file;

   # create path preceding file if path doesn't exist

   $this->make_dir(
      $root . $path,
      exists $in->{dbitmask} && defined $in->{dbitmask}
         ? $in->{dbitmask}
         : oct 777
   ) unless -e $root . $path;

   # if file already exists, check if we can write to it
   if ( -e $clean_name ) {

      return $this->_throw(
         'cant fwrite' => {
            filename   => $clean_name,
            dirname    => $root . $path,
            opts       => $in,
         }
      ) unless -w $clean_name;
   }
   else {

      # if file doesn't exist, see if we can create it
      return $this->_throw(
         'cant fcreate' => {
            filename    => $clean_name,
            dirname     => $root . $path,
            opts        => $in,
         }
      ) unless -w $root . $path;
   }

   # if you use the no_lock option, please consider the risks

   if ( $$in{no_lock} || !$USE_FLOCK ) {

      # only non-existent files get bitmask arguments
      if ( -e $clean_name ) {

         sysopen
            $write_fh,
            $clean_name,
            $$MODES{sysopen}{ $mode }
         or return $this->_throw(
               'bad open'   => {
                  filename  => $clean_name,
                  mode      => $mode,
                  exception => $!,
                  cmd       => qq($clean_name, $$MODES{sysopen}{ $mode }),
                  opts      => $in,
               }
            );
      }
      else {

         sysopen
            $write_fh,
            $clean_name,
            $$MODES{sysopen}{ $mode },
            $bitmask
         or return $this->_throw(
            'bad open'   => {
               filename  => $clean_name,
               mode      => $mode,
               exception => $!,
               cmd       => qq($clean_name, $$MODES{sysopen}{$mode}, $bitmask),
               opts      => $in,
            }
         );
      }
   }
   else {
      # open read-only first to safely check if we can get a lock.
      if ( -e $clean_name ) {

         open $write_fh, '<', $clean_name or
            return $this->_throw(
               'bad open'   => {
                  filename  => $clean_name,
                  mode      => 'read',
                  exception => $!,
                  cmd       => $mode . $clean_name,
                  opts      => $in,
               }
            );

         # lock file before I/O on platforms that support it
         my $lockstat = $this->_seize( $clean_name, $write_fh );

         return unless $lockstat;

         sysopen
            $write_fh,
            $clean_name,
            $$MODES{sysopen}{ $mode }
         or return $this->_throw(
            'bad open'   => {
               filename  => $clean_name,
               mode      => $mode,
               opts      => $in,
               exception => $!,
               cmd       => qq($clean_name, $$MODES{sysopen}{ $mode }),
            }
         );
      }
      else { # only non-existent files get bitmask arguments

         sysopen
            $write_fh,
            $clean_name,
            $$MODES{sysopen}{ $mode },
            $bitmask
         or return $this->_throw(
            'bad open'   => {
               filename  => $clean_name,
               mode      => $mode,
               opts      => $in,
               exception => $!,
               cmd       => qq($clean_name, $$MODES{sysopen}{$mode}, $bitmask),
            }
         );

         # lock file before I/O on platforms that support it
         my $lockstat = $this->_seize( $clean_name, $write_fh );

         return unless $lockstat;
      }

      # now truncate
      if ( $mode ne 'append' ) {

         truncate( $write_fh, 0 ) or return $this->_throw(
            'bad systrunc' => {
               filename    => $clean_name,
               exception   => $!,
               opts        => $in,
            }
         );
      }
   }

   CORE::binmode( $write_fh ) if $in->{binmode};

   syswrite( $write_fh, $content );

   # release lock on the file

   $this->_release( $write_fh ) unless $$in{no_lock} || !$USE_FLOCK;

   close $write_fh or
      return $this->_throw(
         'bad close'  => {
            filename  => $clean_name,
            mode      => $mode,
            exception => $!,
            opts      => $in,
         }
      );

   return 1;
}


# --------------------------------------------------------
# File::Util::_seize()
# --------------------------------------------------------
sub _seize {
   my ( $this, $file, $fh ) = @_;

   return $this->_throw( 'no handle passed to _seize.' ) unless $fh;

   $file = defined $file ? $file : ''; # yes, even files named "0" are allowed

   return $this->_throw( 'no file name passed to _seize.' ) unless length $file;

   # forget seizing if system can't flock
   return $fh if !$CAN_FLOCK;

   my @policy = @ONLOCKFAIL;

   # seize filehandle, return it if lock is successful

   while ( @policy ) {

      my $fh = &{ $_LOCKS->{ shift @policy } }( $this, $file, $fh );

      return $fh if $fh || !scalar @policy;
   }

   return $fh;
}


# --------------------------------------------------------
# File::Util::_release()
# --------------------------------------------------------
sub _release {

   my ( $this, $fh ) = @_;

   return $this->_throw( 'not a filehandle.', { argtype => ref $fh } )
      unless $fh && ref $fh eq 'GLOB';

   if ( $CAN_FLOCK ) { flock $fh, &Fcntl::LOCK_UN }
   return 1;
}


# --------------------------------------------------------
# File::Util::valid_filename()
# --------------------------------------------------------
sub valid_filename {
   my $f = _myargs( @_ );

   $f =~ s/$WINROOT//; # windows abs paths would throw this off

   $f !~ /$ILLEGAL_CHR/ ? 1 : undef;
}


# --------------------------------------------------------
# File::Util::strip_path()
# --------------------------------------------------------
sub strip_path { pop @{[ '', split /$DIRSPLIT/, _myargs( @_ ) ]} || '' }


# --------------------------------------------------------
# File::Util::atomize_path()
# --------------------------------------------------------
sub atomize_path {
   my $fqfn = _myargs( @_ );

   $fqfn =~ m/$ATOMIZER/;

   my $root = $1 || '';
   my $path = $2 || '';
   my $file = $3 || '';

   return( $root, $path, $file );
}


# --------------------------------------------------------
# File::Util::atomize_path()
# --------------------------------------------------------
sub split_path {
   my $path = _myargs( @_ );

   # find root of tree (if path was absolute)
   my ( $root, $branch, $leaf ) = atomize_path( $path );

   my @path_dirs = split /$DIRSPLIT/o, $branch;

   unshift @path_dirs, $root if $root;
   push    @path_dirs, $leaf if $leaf;

   return @path_dirs;
}


# --------------------------------------------------------
# File::Util::line_count()
# --------------------------------------------------------
sub line_count {
   my( $this, $file ) = @_;
   my $buff  = '';
   my $lines = 0;
   my $cmd   = '<' . $file;

   open my $fh, '<', $file or
      return $this->_throw(
         'bad open',
         {
            'filename'  => $file,
            'mode'      => 'read',
            'exception' => $!,
            'cmd'       => $cmd,
         }
      );

   while ( sysread( $fh, $buff, 4096 ) ) {

      $lines += $buff =~ tr/\n//;

      $buff  = '';
   }

   close $fh;

   return $lines;
}


# --------------------------------------------------------
# File::Util::bitmask()
# --------------------------------------------------------
sub bitmask {
   my $f = _myargs( @_ );

   defined $f and -e $f ? sprintf('%04o',(stat($f))[2] & oct 777) : undef
}


# --------------------------------------------------------
# File::Util::can_flock()
# --------------------------------------------------------
sub can_flock { $CAN_FLOCK }


# File::Util::--------------------------------------------
#   can_read(),   can_write()
# --------------------------------------------------------
sub can_read  { my $f = _myargs( @_ ); defined $f ? -r $f : undef }
sub can_write { my $f = _myargs( @_ ); defined $f ? -w $f : undef }


# --------------------------------------------------------
# File::Util::created()
# --------------------------------------------------------
sub created {
   my $f = _myargs( @_ );

   defined $f and -e $f ? $^T - ((-M $f) * 60 * 60 * 24) : undef
}


# --------------------------------------------------------
# File::Util::ebcdic()
# --------------------------------------------------------
sub ebcdic { $EBCDIC }


# --------------------------------------------------------
# File::Util::escape_filename()
# --------------------------------------------------------
sub escape_filename {
   my $opts = _remove_opts( \@_ );
   my( $file, $escape, $also ) = _myargs( @_ );

   return '' unless defined $file;

   $escape = '_' if !defined($escape);

   $file = strip_path($file) if $opts->{strip_path};

   if ( $also ) { $file =~ s/\Q$also\E/$escape/g }

   $file =~ s/$ILLEGAL_CHR/$escape/g;
   $file =~ s/$DIRSPLIT/$escape/g;

   $file
}


# --------------------------------------------------------
# File::Util::existent()
# --------------------------------------------------------
sub existent { my $f = _myargs( @_ ); defined $f ? -e $f : undef }


# --------------------------------------------------------
# File::Util::touch()
# --------------------------------------------------------
sub touch {
   my $this = shift @_;
   my $file = shift( @_ ) || '';
   my $path;

   return $this->_throw(
      'no input',
      {
         meth    => 'touch',
         missing => 'a file name or file handle reference',
         opts    => { },
      }
   ) unless defined $file && length $file;

   $path = $this->return_path( $file );

   # see if the file exists already and is a directory
   return $this->_throw(
      'cant touch on a dir',
      {
         filename => $file,
         dirname  => $path || '',
         opts     => { },
      }
   ) if -e $file && -d $file;

   # it's good to know beforehand whether or not we have permission to open
   # and read from this file allowing us to handle such an exception before
   # it handles us.

   # first check the readability of the file's housing dir
   return $this->_throw(
      'cant dread',
      {
         filename => $file,
         dirname  => $path,
         opts     => { },
      }
   ) if ( -e $path && !-r $path );

   $this->make_dir( $path ) unless -e $path;

   # create the file if it doesn't exist (like the *nix touch command does)
   $this->write_file(
      filename => $file,
      content  => '',
      { empty_writes_OK => 1 }
   ) unless -e $file;

   my $now = time();

   # return
   return utime $now, $now, $file;
}


# --------------------------------------------------------
# File::Util::file_type()
# --------------------------------------------------------
sub file_type {
   my $f = _myargs( @_ );

   return unless defined $f and -e $f;

   my @ret;

   push @ret, 'PLAIN'     if -f $f;   push @ret, 'TEXT'      if -T $f;
   push @ret, 'BINARY'    if -B $f;   push @ret, 'DIRECTORY' if -d $f;
   push @ret, 'SYMLINK'   if -l $f;   push @ret, 'PIPE'      if -p $f;
   push @ret, 'SOCKET'    if -S $f;   push @ret, 'BLOCK'     if -b $f;
   push @ret, 'CHARACTER' if -c $f;

   ## no critic
   push @ret, 'TTY'       if -t $f;
   ## use critic

   push @ret, 'ERROR: Cannot determine file type' unless scalar @ret;

   return @ret;
}


# --------------------------------------------------------
# File::Util::flock_rules()
# --------------------------------------------------------
sub flock_rules {
   my $this   = shift(@_);
   my @rules  = _myargs( @_ );

   return @ONLOCKFAIL unless scalar @rules;

   my %valid = qw/
      NOBLOCKEX   NOBLOCKEX
      NOBLOCKSH   NOBLOCKSH
      BLOCKEX     BLOCKEX
      BLOCKSH     BLOCKSH
      FAIL        FAIL
      WARN        WARN
      IGNORE      IGNORE
      UNDEF       UNDEF
      ZERO        ZERO /;

   map {
      return $this->_throw('bad flock rules', { 'bad' => $_, 'all' => \@rules })
      unless exists $valid{ $_ }
   } @rules;

   @ONLOCKFAIL = @rules;

   @ONLOCKFAIL
}


# --------------------------------------------------------
# File::Util::isbin()
# --------------------------------------------------------
sub isbin { my $f = _myargs( @_ ); defined $f ? -B $f : undef }


# --------------------------------------------------------
# File::Util::last_access()
# --------------------------------------------------------
sub last_access {
   my $f = _myargs( @_ ); $f ||= '';

   return unless -e $f;

   # return the last accessed time of $f
   $^T - ((-A $f) * 60 * 60 * 24)
}


# --------------------------------------------------------
# File::Util::last_modified()
# --------------------------------------------------------
sub last_modified {
   my $f = _myargs( @_ ); $f ||= '';

   return unless -e $f;

   # return the last modified time of $f
   $^T - ((-M $f) * 60 * 60 * 24)
}


# --------------------------------------------------------
# File::Util::last_changed()
# --------------------------------------------------------
sub last_changed {
   my $f = _myargs( @_ ); $f ||= '';

   return unless -e $f;

   # return the last changed time of $f
   $^T - ((-C $f) * 60 * 60 * 24)
}


# --------------------------------------------------------
# File::Util::load_dir()
# --------------------------------------------------------
sub load_dir {
   my $this = shift @_;
   my $opts = $this->_remove_opts( \@_ );
   my $dir  = shift @_;

   my @files    = ( );
   my $dir_hash = { };
   my $dir_list = [ ];

   $dir ||= '';

   return $this->_throw(
      'no input' => {
         meth    => 'load_dir',
         missing => 'a directory name',
         opts    => $opts,
      }
   ) unless length $dir;

   @files = $this->list_dir( $dir => { files_only => 1 } );

   # map the content of each file into a hash key-value element where the
   # key name for each file is the name of the file
   if ( !$opts->{as_list} && !$opts->{as_listref} ) {

      foreach ( @files ) {

         $dir_hash->{ $_ } = $this->load_file( $dir . SL . $_ );
      }

      return $dir_hash;
   }
   else {

      foreach ( @files ) {

         push @$dir_list, $this->load_file( $dir . SL . $_ );
      }

      return $dir_list if $opts->{as_listref};

      return @$dir_list;
   }

   return $dir_hash;
}


# --------------------------------------------------------
# File::Util::make_dir()
# --------------------------------------------------------
sub make_dir {
   my $this = shift @_;
   my $opts = $this->_remove_opts( \@_ );
   my( $dir, $bitmask ) = @_;

   $bitmask = defined $bitmask ? $bitmask : $opts->{bitmask};
   $bitmask ||= oct 777;

   if ( $opts->{if_not_exists} ) {

      if ( -e $dir ) {

         return $dir if -d $dir;

         return $this->_throw(
            'called mkdir on a file',
            {
               filename => $dir,
               dirname  => join( SL, split /$DIRSPLIT/, $dir ) . SL
            }
         );
      }
   }
   else {

      if ( -e $dir ) {

         return $this->_throw(
            'called mkdir on a file',
            {
               filename => $dir,
               dirname  => join( SL, split /$DIRSPLIT/, $dir ) . SL
            }
         ) unless -d $dir;

         return $this->_throw(
            'make_dir target exists',
            {
               dirname  => $dir,
               filetype => [ $this->file_type( $dir ) ],
            }
         );
      }
   }

   # if the call to this method didn't include a directory name to create,
   # then complain about it
   return $this->_throw(
      'no input',
      {
         meth    => 'make_dir',
         missing => 'a directory name',
      }
   ) unless defined $dir && length $dir;

   # if prospective directory name contains 2+ dir separators in sequence then
   # this is a syntax error we need to whine about
   {
      my $try_dir = $dir;

      $try_dir =~ s/$WINROOT//; # windows abs paths would throw this off

      return $this->_throw(
         'bad chars',
         {
            string  => $dir,
            purpose => 'the name of a directory',
         }
      ) if $try_dir =~ /(?:$DIRSPLIT){2,}/;
   }

   $dir =~ s/$DIRSPLIT$// unless $dir eq $DIRSPLIT;

   my ( $root, $path ) = atomize_path( $dir . SL );

   my @dirs_in_path = split /$DIRSPLIT/, $path;

   # if prospective file name has illegal chars then complain
   foreach ( @dirs_in_path ) {

      return $this->_throw(
         'bad chars',
         {
            string  => $_,
            purpose => 'the name of a file or directory',
            opts    => $opts,
         }
      ) if !$this->valid_filename( $_ );
   }

   # do this AFTER the above check!!
   unshift @dirs_in_path, $root if $root;

   # qualify each subdir in @dirs_in_path by prepending its preceeding dir
   # names to it. Above, "/foo/bar/baz" becomes ("/", "foo", "bar", "baz")
   # and below it becomes ("/", "/foo", "/foo/bar", "/foo/bar/baz")

   if ( @dirs_in_path > 1 ) {
      for ( my $depth = 1; $depth < @dirs_in_path; ++$depth ) {

         if ( $dirs_in_path[ $depth-1 ] eq SL ) {

            $dirs_in_path[ $depth ] = SL . $dirs_in_path[ $depth ]
         }
         else {

            $dirs_in_path[ $depth ] =
               join SL, @dirs_in_path[ ( $depth - 1 ) .. $depth ]
         }
      }
   }

   my $i = 0;

   foreach ( @dirs_in_path ) {
      my $dir = $_;
      my $up  = ( $i > 0 ) ? $dirs_in_path[ $i - 1 ] : '..';

      ++$i;

      if ( -e $dir && !-d $dir ) {

         return $this->_throw(
            'called mkdir on a file',
            {
               'filename'  => $dir,
               'dirname'   => $up . SL,
            }
         );
      }

      next if -e $dir;

      # it's good to know beforehand whether or not we have permission to
      # create dirs here, which allows us to handle such an exception
      # before it handles us.
      return $this->_throw(
         'cant dcreate',
         {
            dirname  => $dir,
            parentd  => $up,
         }
      ) unless -w $up;

      mkdir( $dir, $bitmask ) or
         return $this->_throw(
            'bad make_dir',
            {
               exception => $!,
               dirname   => $dir,
               bitmask   => $bitmask,
            }
         );
   }

   return $dir;
}


# --------------------------------------------------------
# File::Util::max_dives()
# --------------------------------------------------------
sub max_dives {
   my $arg = _myargs( @_ );

   if ( defined $arg ) {

      return File::Util->new()->_throw('bad maxdives') if $arg !~ /\D/o;

      $MAXDIVES = $arg;
   }

   return $MAXDIVES;
}


# --------------------------------------------------------
# File::Util::readlimt()
# --------------------------------------------------------
sub readlimit {
   my $arg = _myargs( @_ );

   if ( defined $arg ) {

      return File::Util->new()->_throw
         (
            'bad readlimit' => { bad => $arg }
         ) if $arg !~ /\D/o;

      $READLIMIT = $arg;
   }

   return $READLIMIT;
}


# --------------------------------------------------------
# File::Util::needs_binmode()
# --------------------------------------------------------
sub needs_binmode { $NEEDS_BINMODE }


# --------------------------------------------------------
# File::Util::open_handle()
# --------------------------------------------------------
sub open_handle {
   my $this     = shift @_;
   my $opts     = $this->_remove_opts( \@_ );
   my $in       = $this->_names_values( @_ );
   my $file     = '';
   my $mode     = '';
   my $bitmask  = $in->{bitmask} || oct 777;
   my $raw_name = $file;
   my $fh; # will be the lexical file handle scoped to this method
   my ( $root, $path, $clean_name, @dirs ) =
      ( '',    '',    '',          ()    );

   # get name of file when passed in as a name/value pair...

   $file =
      exists  $in->{filename} &&
      defined $in->{filename} &&
      length  $in->{filename}
         ? $in->{filename}
         : exists  $in->{file} &&
           defined $in->{file} &&
           length  $in->{file}
            ? $in->{file}
            : '';

   # ...or fall back to support of two-argument form of invocation

   my $maybe_file = shift @_; $maybe_file = '' if !defined $maybe_file;
   my $maybe_mode = shift @_; $maybe_mode = '' if !defined $maybe_mode;

   $file = $maybe_file if !ref $maybe_file && $file eq '';
   $mode =
      !ref $maybe_mode &&
      !exists $in->{mode}
         ? $maybe_mode
         : $in->{mode};

   $mode ||= 'read';

   $raw_name = $file; # preserve original filename input before line below:

   ( $root, $path, $file ) = atomize_path( $file );

   # begin user input validation/sanitation sequence

   # if the call to this method didn't include a filename to which the caller
   # wants us to write, then complain about it
   return $this->_throw(
      'no input',
      {
         meth    => 'open_handle',
         missing => 'a file name to create, write, read/write, or append',
         opts    => $opts,
      }
   ) unless length $file;

   # if prospective filename contains 2+ dir separators in sequence then
   # this is a syntax error we need to whine about
   {
      my $try_filename = $raw_name;

      $try_filename =~ s/$WINROOT//; # windows abs paths would throw this off

      return $this->_throw(
         'bad chars',
         {
            string  => $raw_name,
            purpose => 'the name of a file or directory',
            opts    => $opts,
         }
      ) if $try_filename =~ /(?:$DIRSPLIT){2,}/;
   }

   # determine existance of the file path, make directory(ies) for the
   # path if the full directory path doesn't exist
   @dirs = split /$DIRSPLIT/, $path;

   # if prospective file name has illegal chars then complain
   foreach ( @dirs ) {

      return $this->_throw(
         'bad chars',
         {
            string  => $_,
            purpose => 'the name of a file or directory',
            opts    => $opts,
         }
      ) if !$this->valid_filename( $_ );
   }

   # do this AFTER the above check!!
   unshift @dirs, $root if $root;

   # make sure that open mode is a valid mode
   if (
      !exists $opts->{use_sysopen} &&
      !defined $opts->{use_sysopen}
   ) {
      # native Perl open modes
      unless (
         exists $$MODES{popen}{ $mode } &&
         defined $$MODES{popen}{ $mode }
      ) {
         return $this->_throw(
            'bad openmode popen',
            {
               meth     => 'open_handle',
               filename => $raw_name,
               badmode  => $mode,
               opts     => $opts,
            }
         )
      }
   }
   else {
      # system open modes
      unless (
         exists $$MODES{sysopen}{ $mode } &&
         defined $$MODES{sysopen}{ $mode }
      ) {
         return $this->_throw(
            'bad openmode sysopen',
            {
               meth     => 'open_handle',
               filename => $raw_name,
               badmode  => $mode,
               opts     => $opts,
            }
         )
      }
   }

   # cleanup file name - if path is relative, normalize it
   #    - /foo/bar/baz.txt stays as /foo/bar/baz.txt
   #    - foo/bar/baz.txt  becomes ./foo/bar/baz.txt
   #    - baz.txt          stays as baz.txt
   if ( !length $root && !length $path ) {

      $path = '.' . SL;
   }
   else { # otherwise path normalized at end

      $path .= SL;
   }

   # final clean filename assembled
   $clean_name = $root . $path . $file;

   # create path preceding file if path doesn't exist
   $this->make_dir(
      $root . $path,
      exists $in->{dbitmask} && defined $in->{dbitmask}
         ? $in->{dbitmask}
         : oct 777
   ) unless -e $root . $path;

   # sanity checks based on requested mode
   if (
         $mode eq 'write'     ||
         $mode eq 'append'    ||
         $mode eq 'rwcreate'  ||
         $mode eq 'rwclobber' ||
         $mode eq 'rwappend'
   ) {
      # Check whether or not we have permission to open and perform writes
      # on this file.

      if ( -e $clean_name ) {

         return $this->_throw(
            'cant fwrite',
            {
               filename => $clean_name,
               dirname  => $root . $path,
               opts     => $opts,
            }
         ) unless -w $clean_name;
      }
      else {
         # If file doesn't exist and the path isn't writable, the error is
         # one of unallowed creation.
         return $this->_throw(
            'cant fcreate',
            {
               filename => $clean_name,
               dirname  => $root . $path,
               opts     => $opts,
            }
         ) unless -w $root . $path;
      }
   }
   elsif ( $mode eq 'read' || $mode eq 'rwupdate' ) {
      # Check whether or not we have permission to open and perform reads
      # on this file, starting with file's housing directory.
      return $this->_throw(
         'cant dread',
         {
            filename => $clean_name,
            dirname  => $root . $path,
            opts     => $opts,
         }
      ) unless -r $root . $path;

      # Seems obvious, but we can't read non-existent files
      return $this->_throw(
         'cant fread not found',
         {
            filename => $clean_name,
            dirname  => $root . $path,
            opts     => $opts,
         }
      ) unless -e $clean_name;

      # Check the readability of the file itself
      return $this->_throw(
         'cant fread',
         {
            filename => $clean_name,
            dirname  => $root . $path,
            opts     => $opts,
         }
      ) unless -r $clean_name;
   }
   else {
      return $this->_throw(
         'no input',
         {
            meth    => 'open_handle',
            missing => q{a valid IO mode. (eg- 'read', 'write'...)},
            opts    => $opts,
         }
      );
   }
   # input validation sequence finished

   if ( $$opts{no_lock} || !$USE_FLOCK ) {
      if (
         !exists $opts->{use_sysopen} &&
         !defined $opts->{use_sysopen}
      ) { # perl open
         # get open mode
         $mode = $$MODES{popen}{ $mode };

         open $fh, $mode, $clean_name or
            return $this->_throw(
               'bad open',
               {
                  filename  => $clean_name,
                  mode      => $mode,
                  exception => $!,
                  cmd       => $mode . $clean_name,
                  opts      => $opts,
               }
            );
      }
      else { # sysopen
         # get open mode
         $mode = $$MODES{sysopen}{ $mode };

         sysopen( $fh, $clean_name, $$MODES{sysopen}{ $mode } ) or
            return $this->_throw(
               'bad open',
               {
                  filename  => $clean_name,
                  mode      => $mode,
                  exception => $!,
                  cmd       => qq($clean_name, $$MODES{sysopen}{ $mode }),
                  opts      => $opts,
               }
            );
      }
   }
   else {
      if (
         !exists $opts->{use_sysopen} &&
         !defined $opts->{use_sysopen}
      ) { # perl open
         # open read-only first to safely check if we can get a lock.
         if ( -e $clean_name ) {

            open $fh, '<', $clean_name or
               return $this->_throw(
                  'bad open',
                  {
                     filename  => $clean_name,
                     mode      => 'read',
                     exception => $!,
                     cmd       => $mode . $clean_name,
                     opts      => $opts,
                  }
               );

            # lock file before I/O on platforms that support it
            my $lockstat = $this->_seize( $clean_name, $fh );

            return $lockstat unless $lockstat;

            if ( $mode ne 'read' ) {

               open $fh, $$MODES{popen}{ $mode }, $clean_name or
                  return $this->_throw(
                     'bad open',
                     {
                        exception => $!,
                        filename  => $clean_name,
                        mode      => $mode,
                        opts      => $opts,
                        cmd       => $$MODES{popen}{ $mode } . $clean_name,
                     }
                  );
            }
         }
         else {
            open $fh, $$MODES{popen}{ $mode }, $clean_name or
               return $this->_throw(
                  'bad open',
                  {
                     exception => $!,
                     filename  => $clean_name,
                     mode      => $mode,
                     opts      => $opts,
                     cmd       => $$MODES{popen}{ $mode } . $clean_name,
                  }
               );

            # lock file before I/O on platforms that support it
            my $lockstat = $this->_seize( $clean_name, $fh );

            return $lockstat unless $lockstat;
         }
      }
      else { # sysopen
         # open read-only first to safely check if we can get a lock.
         if ( -e $clean_name ) {

            open $fh, '<', $clean_name or
               return $this->_throw(
                  'bad open',
                  {
                     filename  => $clean_name,
                     mode      => 'read',
                     exception => $!,
                     cmd       => $mode . $clean_name,
                     opts      => $opts,
                  }
               );

            # lock file before I/O on platforms that support it
            my $lockstat = $this->_seize( $clean_name, $fh );

            return $lockstat unless $lockstat;

            sysopen( $fh, $clean_name, $$MODES{sysopen}{ $mode } )
               or return $this->_throw(
                  'bad open',
                  {
                     filename  => $clean_name,
                     mode      => $mode,
                     opts      => $opts,
                     exception => $!,
                     cmd       => qq($clean_name, $$MODES{sysopen}{ $mode }),
                  }
               );
         }
         else { # only non-existent files get bitmask arguments
            sysopen(
               $fh,
               $clean_name,
               $$MODES{sysopen}{ $mode },
               $bitmask
            ) or return $this->_throw(
               'bad open',
               {
                  filename  => $clean_name,
                  mode      => $mode,
                  opts      => $opts,
                  exception => $!,
                  cmd       => qq($clean_name, $$MODES{sysopen}{$mode}, $bitmask),
               }
            );

            # lock file before I/O on platforms that support it
            my $lockstat = $this->_seize( $clean_name, $fh );

            return $lockstat unless $lockstat;
         }
      }
   }

   # call binmode on the filehandle if it was requested
   CORE::binmode( $fh ) if $in->{binmode} || $opts->{binmode};

   # return file handle reference to the caller
   return $fh;
}


# --------------------------------------------------------
# File::Util::unlock_open_handle()
# --------------------------------------------------------
sub unlock_open_handle {
   my( $this, $fh ) = @_;

   return 1 if !$USE_FLOCK;

   my $ref_type = ref \$fh || '';

   return $this->_throw( 'not a filehandle' => { argtype => $ref_type } )
      unless $fh && $ref_type eq 'GLOB';

   return flock( $fh, &Fcntl::LOCK_UN ) if $CAN_FLOCK;

   return 1;
}


# --------------------------------------------------------
# File::Util::return_path()
# --------------------------------------------------------
sub return_path { my $f = _myargs( @_ ); $f =~ s/(^.*)$DIRSPLIT.*/$1/o; $f }


# --------------------------------------------------------
# File::Util::size()
# --------------------------------------------------------
sub size { my $f = _myargs( @_ ); $f ||= ''; return unless -e $f; -s $f }


# --------------------------------------------------------
# File::Util::trunc()
# --------------------------------------------------------
sub trunc { $_[0]->write_file( { mode => trunc => file => $_[1] } ) }


# --------------------------------------------------------
# File::Util::use_flock()
# --------------------------------------------------------
sub use_flock {
   my $arg = _myargs( @_ );

   $USE_FLOCK = !!$arg if defined $arg;

   return $USE_FLOCK;
}


# --------------------------------------------------------
# File::Util::AUTOLOAD() # only load error libs for errors
# --------------------------------------------------------
sub AUTOLOAD {

   ( my $name = our $AUTOLOAD ) =~ s/.*:://;

   if ( $name eq '_throw' )
   {
      if ( $_[0]->{opts}->{diag} )
      {
         require File::Util::Exception::Diagnostic;

         File::Util::Exception::Diagnostic->import( qw( _throw _errors ) );
      }
      else
      {
         require File::Util::Exception::Standard;

         File::Util::Exception::Standard->import( qw( _throw _errors ) );
      }

      goto \&_throw;
   }
}


# --------------------------------------------------------
# File::Util::DESTROY()
# --------------------------------------------------------
sub DESTROY { }

1;


__END__

=pod

=head1 NAME

File::Util - Easy, versatile, portable file handling

=head1 DESCRIPTION

File::Util provides a comprehensive toolbox of utilities to automate all
kinds of common tasks on files and directories.  Its purpose is to do so
in the most B<portable> manner possible so that users of this module won't
have to worry about whether their programs will work on other operating systems
and/or architectures.  It works on Linux, Windows, Mac, BSD, Unix and others.

File::Util is written B<purely in Perl>, and requires no compiler or make
utility on your system in order to install and run it.

File::Util also aims to be as backward compatible as possible, running without
problems on Perl installations as old as 5.006.  You are encouraged to run
File::Util on Perl version 5.8 and above.

=head1 SYNOPSIS

   use File::Util;

   # create a new File::Util object
   my $f = File::Util->new();

   # load content into a variable, be it text, or binary, either works
   my $content = $f->load_file( 'Meeting Notes.txt' );

   # wrangle text
   $content =~ s/this/that/g;

   # re-write the file with your changes
   $f->write_file(
      file => 'Meeting Notes.txt',
      content => $content,
   );

   # try binary this time
   my $binary_content = $f->load_file( 'cat-movie.avi' );

   # get some image data from somewhere...
   my $picture_data = get_image_upload();

   # ...and write a binary image file, using some other options as well
   $f->write_file(
      file => 'llama.jpg',
      content => $picture_data,
      { binmode => 1, bitmask => oct 644 }
   );

   # load a file into an array, line by line
   my @lines = $f->load_file( 'file.txt' => { as_lines => 1 } );

   # get an open file handle for reading
   my $fh = $f->open_handle( file => 'Ian likes cats.txt', mode => 'read' );

   while ( my $line = <$fh> ) { # read the file, line by line

      # ... do stuff
   }

   close $fh or die $!; # don't forget to close ;-)

   # get an open file handle for writing
   $fh = $f->open_handle(
      file => 'John prefers dachshunds.txt',
      mode => 'write'
   );

   print $fh 'Shout out to Bob!';

   close $fh or die $!; # _never_ forget to close ;-)

   # get a listing of files, recursively, skipping directories
   my @files = $f->list_dir( '/var/tmp' => { files_only => 1, recurse => 1 } );

   # get a listing of text files, recursively
   my @textfiles = $f->list_dir(
      '/var/tmp' => {
         files_match => qr/\.txt$/,
         files_only  => 1,
         recurse     => 1,
      }
   );

   # walk a directory, using an anonymous function or function ref as a
   # callback (higher order Perl)
   $f->list_dir( '/home/larry' => {
      recurse  => 1,
      callback => sub {
         my ( $selfdir, $subdirs, $files ) = @_;

         print "In $selfdir there are...\n";

         print scalar @$subdirs . " subdirectories, and ";
         print scalar @$files   . " files\n";

         for my $file ( @$files ) {

            # ... do something with $file
         }
      },
   } );

   # get an entire directory tree as a hierarchal datastructure reference
   my $tree = $f->list_dir( '/my/podcasts' => { as_tree => 1 } );

   # see if you have permission to write to a file, then append to it
   # using an auto-flock'd filehandle (for operating systems that support flock)
   # ...you can also use the write_file() method in append mode as well...

   if ( $f->can_write( 'captains.log' ) ) {

      my $fh = $f->open_handle(
         file => 'captains.log',
         mode => 'append'
      );

      print $fh "Captain's log, stardate 41153.7.  Our destination is...";

      close $fh or die $!;
   }
   else { # ...or warn the crew

      warn "Trouble on the bridge, the Captain can't access his log!";
   }

   # get the number of lines in a file
   my $log_line_count = $f->line_count( '/var/log/messages' );

   # the next several examples show how to get different information about files

   print "My file has a bitmask of " . $f->bitmask( 'my.file' );

   print "My file is a " . join(', ', $f->file_type( 'my.file' )) . " file.";

   warn 'This file is binary!' if $f->isbin( 'my.file' );

   print 'My file was last modified on ' .
      scalar localtime $f->last_modified( 'my.file' );

...and B<_lots_> more, See the L<File::Util::Manual> for details.

=head1 INSTALLATION

To install this module type the following at the command prompt:

   perl Build.PL
   perl Build
   perl Build test
   sudo perl Build install

On Windows systems, the "sudo" part of the command may be omitted, but you
will need to run the rest of the install command with Administrative privileges

=head1 DOCUMENTATION

There's more than just this document!  Take a look at the L<File::Util::Manual>,
the L<File::Util::Manual::Examples>, and the L<File::Util::Cookbook>.

=head1 METHODS

File::Util exposes the following public methods.

B<Each of which are covered in the L<File::Util::Manual>>, which has more room for
the detailed explanation that is provided there.

This is just an itemized table of contents.

=over

=item atomize_path         I<(see L<atomize_path|File::Util::Manual/atomize_path>)>

=item bitmask              I<(see L<bitmask|File::Util::Manual/bitmask>)>

=item can_flock            I<(see L<can_flock|File::Util::Manual/can_flock>)>

=item can_read             I<(see L<can_read|File::Util::Manual/can_read>)>

=item can_write            I<(see L<can_write|File::Util::Manual/can_write>)>

=item created              I<(see L<created|File::Util::Manual/created>)>

=item ebcdic               I<(see L<ebcdic|File::Util::Manual/ebcdic>)>

=item escape_filename      I<(see L<escape_filename|File::Util::Manual/escape_filename>)>

=item existent             I<(see L<existent|File::Util::Manual/existent>)>

=item file_type            I<(see L<file_type|File::Util::Manual/file_type>)>

=item flock_rules          I<(see L<flock_rules|File::Util::Manual/flock_rules>)>

=item isbin                I<(see L<isbin|File::Util::Manual/isbin>)>

=item last_access          I<(see L<last_access|File::Util::Manual/last_access>)>

=item last_changed         I<(see L<last_changed|File::Util::Manual/last_changed>)>

=item last_modified        I<(see L<last_modified|File::Util::Manual/last_modified>)>

=item line_count           I<(see L<line_count|File::Util::Manual/line_count>)>

=item list_dir             I<(see L<list_dir|File::Util::Manual/list_dir>)>

=item load_dir             I<(see L<load_dir|File::Util::Manual/load_dir>)>

=item load_file            I<(see L<load_file|File::Util::Manual/load_file>)>

=item make_dir             I<(see L<make_dir|File::Util::Manual/make_dir>)>

=item max_dives            I<(see L<max_dives|File::Util::Manual/max_dives>)>

=item needs_binmode        I<(see L<needs_binmode|File::Util::Manual/needs_binmode>)>

=item new                  I<(see L<new|File::Util::Manual/new>)>

=item open_handle          I<(see L<open_handle|File::Util::Manual/open_handle>)>

=item readlimit            I<(see L<readlimit|File::Util::Manual/readlimit>)>

=item return_path          I<(see L<return_path|File::Util::Manual/return_path>)>

=item size                 I<(see L<size|File::Util::Manual/size>)>

=item split_path           I<(see L<split_path|File::Util::Manual/split_path>)>

=item strip_path           I<(see L<strip_path|File::Util::Manual/strip_path>)>

=item touch                I<(see L<touch|File::Util::Manual/touch>)>

=item trunc                I<(see L<trunc|File::Util::Manual/trunc>)>

=item unlock_open_handle   I<(see L<unlock_open_handle|File::Util::Manual/unlock_open_handle>)>

=item use_flock            I<(see L<use_flock|File::Util::Manual/use_flock>)>

=item valid_filename       I<(see L<valid_filename|File::Util::Manual/valid_filename>)>

=item write_file           I<(see L<write_file|File::Util::Manual/write_file>)>

=back

=head1 EXPORTED SYMBOLS

Exports nothing by default.  File::Util fully respects your namespace.
You can, however, ask it for certain things (below).

=head2 @EXPORT_OK

The following symbols comprise C<@File::Util::EXPORT_OK>), and as such are
available for import to your namespace only upon request.  They can be
used either as object methods or like regular subroutines in your program.

To get any of these functions/symbols into your namespace without having
to use them as an object method, use this kind of syntax:

C<use File::Util qw( strip_path NL );>

atomize_path

can_flock

can_read

can_write

created

ebcdic

escape_filename

existent

file_type

isbin

last_access

last_changed

last_modified

NL

needs_binmode

return_path

size

SL

split_path

strip_path

valid_filename

=head2 EXPORT_TAGS

   :all (imports all of @File::Util::EXPORT_OK to your namespace)

   use File::Util qw( :all ); # seldom if ever necessary, but it's an option

=head1 PREREQUISITES

=over

=item L<Exception::Handler>

For graceful and helpful error handling

=item L<Scalar::Util>

For tools that support the better call interface in C<File::Util> versions
4.x and higher

=item L<Perl|perl> 5.006 or better ...

This requirement will increase soon with the advent of unicode support

=back

=head1 EXAMPLES

See L<File::Util::Manual>

=head1 EXAMPLES (Full Programs)

See L<File::Util::Cookbook>

=head1 BUGS

Send bug reports and patches to the CPAN Bug Tracker for File::Util at
L<https://rt.cpan.org/Dist/Display.html?Name=File%3A%3AUtil>

=head1 SUPPORT

If you want to get help, contact the authors (links below in AUTHORS section)

I fully endorse L<http://www.perlmonks.org> as an excellent source of help
with Perl in general.

=head1 CONTRIBUTING

The project website for File::Util is at
L<https://github.com/tommybutler/file-util/wiki>

The git repository for File::Util is on Github at
L<https://github.com/tommybutler/file-util>

Clone it at L<git://github.com/tommybutler/file-util.git>

This project was a private endeavor for too long so don't hesitate to pitch
in. I want to say I very much appreciate the emails, bug reports, patches,
and all those who contribute their time and talents as CPAN testers.

=head1 AUTHORS

Tommy Butler L<http://www.atrixnet.com/contact>

Others Welcome!

=head1 COPYRIGHT

Copyright(C) 2001-2013, Tommy Butler.  All rights reserved.

=head1 LICENSE

This library is free software, you may redistribute it and/or modify it
under the same terms as Perl itself. For more details, see the full text of
the LICENSE file that is included in this distribution.

=head1 LIMITATION OF WARRANTY

This software is distributed in the hope that it will be useful, but without
any warranty; without even the implied warranty of merchantability or fitness
for a particular purpose.

=head1 SEE ALSO

The rest of the documentation:
L<File::Util::Manual>, L<File::Util::Manual::Examples>, L<File::Util::Cookbook>,

Other Useful Modules that do similar things:
L<File::Slurp>, L<File::Spec>, L<Path::Class>

=cut

