use 5.006;
use strict;
use warnings;

package File::Util;

use lib 'lib';

use File::Util::Definitions qw( :all );
use File::Util::Interface::Modern qw( :all );
use File::Util::Exception qw( :all );

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
   size   atomize_path
);

%EXPORT_TAGS = ( all  => [ @EXPORT_OK ] );

# --------------------------------------------------------
# Constructor
# --------------------------------------------------------
sub new {
   my $this = { };

   bless $this, shift @_;

   my $opts = $this->_remove_opts( \@_ ) || {};
   my $in   = $this->_names_values( @_ ) || {};

   @$opts{ keys %$in } = values %$in;

   $this->{opts} = $opts || { };

   $USE_FLOCK  = $opts->{use_flock}
      if exists  $opts->{use_flock}
      && defined $opts->{use_flock};

   $READLIMIT  = $opts->{readlimit}
      if exists  $opts->{readlimit}
      && defined $opts->{readlimit}
      && $opts->{readlimit} !~ /\D/;

   $MAXDIVES   = $opts->{max_dives}
      if exists  $opts->{max_dives}
      && defined $opts->{max_dives}
      && $opts->{max_dives} !~ /\D/;

   return $this;
}


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
# File::Util::list_dir()
# --------------------------------------------------------
sub list_dir {
   my $this = shift @_;
   my $opts = $this->_remove_opts( \@_ );
   my $dir  = shift @_ || '.';
   my $path = $dir;
   my $maxd = $opts->{max_dives} || $MAXDIVES;
   my ( @dirs, @files, @items );

   my $recursing = 0; # flag to dynamicall indicate whether or not this
                      # method is being used recursively for this call

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
      or return $this->_throw(
            'bad opendir' => {
               dirname    => $dir,
               exception  => $!,
               opts       => $opts,
            }
         );

   # read from beginning of the directory (doesn't seem necessary on any
   # platforms I've run code on, but just in case...)
   rewinddir $dir_fh;

   @files = exists $opts->{pattern}
      ? grep /$opts->{pattern}/, readdir $dir_fh
      : readdir $dir_fh;

   @files = exists $opts->{rpattern}
      ? grep /$opts->{rpattern}/, @files
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
   @files = grep { $_ !~ /$FSDOTS/ } @files if $opts->{no_fsdots};

   # prepend full path information to each file name if paths were
   # requested, or if we are recursing.  Then separate the directories
   # and files off into @dirs and @itmes, respectively
   for my $file ( @files ) {

      my $listing = ( $opts->{with_paths} || $recursing == 1 )
         ? $path . SL . $file
         : $file;

      if ( -d $path . SL . $file ) {

         push @dirs, $listing
      }
      else { push @items, $listing }
   }

   if  ( $recursing && !$opts->{override_follow} ) {

      @dirs = grep { $this->strip_path( $_ ) !~ /$FSDOTS/ } @dirs;

      for my $dir ( @dirs ) {

         my @opts = qw(
            --with-paths    --dirs-as-ref
            --files-as-ref  --recursing
            --no-fsdots
         );

         # pattern should work when recursing!
         push @opts, qq(--rpattern=$opts->{rpattern})
            if $opts->{rpattern};

         push @opts, qq(--max-dives=$maxd);

         my @lsts = $this->list_dir( $dir, @opts );

         push @dirs, @{ $lsts[0] }
            if UNIVERSAL::isa( $lsts[0], 'ARRAY' ) && scalar @{ $lsts[0] };

         push @items, @{ $lsts[1] }
            if UNIVERSAL::isa( $lsts[1], 'ARRAY' ) && scalar @{ $lsts[1] };
      }
   }

   if ( $opts->{sl_after_dirs} ) {

      # append directory separator to everything but the "dots"
      $_ .= SL for grep { $_ !~ /$FSDOTS/ } @dirs;
   }

   my $reta = []; my $retb = [];

   if ( $opts->{ignore_case} ) {

      $reta = [ sort { uc $a cmp uc $b } @dirs  ];
      $retb = [ sort { uc $a cmp uc $b } @items ];
   }
   else {

      $reta = [ sort { $a cmp $b } @dirs  ];
      $retb = [ sort { $a cmp $b } @items ];
   }

   return scalar @$reta
      if $opts->{dirs_only} && $opts->{count_only};

   return scalar @$retb
      if $opts->{files_only} && $opts->{count_only};

   return scalar @$reta + scalar @$retb if $opts->{count_only};

   return $reta, $retb if $opts->{as_ref};

   $reta = [ $reta ] if $opts->{dirs_as_ref};
   $retb = [ $retb ] if $opts->{files_as_ref};

   return @$reta if $opts->{dirs_only};
   return @$retb if $opts->{files_only};

   return @$reta, @$retb;
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

   return( \@dots, @out ) if $opts->{'--save-dots'};

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

   my ( $file, $root, $path, $clean_name, $content, $fh_stat, $mode  ) =
      ( '',    '',    '',    '',          '',       '',       'read' );

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

         if ( $buffer < $READLIMIT ) {

            $bytes_read = read( $opts->{FH}, $content, $blocksize );

            $buffer += $bytes_read;
         }
         else {

            return $this->_throw(
               'readlimit exceeded',
               {
                  filename => '<FH>',
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
         if $opts->{'--as-list'};

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
      $$opts{'--no-lock'}        ||
      $$this{opts}{'--no-lock'}  ||
      !$this->use_flock()
   ) {

      # if you use the '--no-lock' option you are probably inefficient
      open $fh, $cmd  or                           ## no critic
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

   if ( $$opts{'--no-lock'} || $$this{opts}{'--no-lock'} ) {

      # if execution gets here, you used the '--no-lock' option, and you
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
      if $opts->{'--as-lines'};

   return $content;
}


# --------------------------------------------------------
# File::Util::write_file()
# --------------------------------------------------------
sub write_file {
   my $this     = shift @_;
   my $opts     = $this->_remove_opts( \@_ );
   my $in       = $this->_names_values( @_ );
   my $file     = $in->{file}    || $in->{filename} || '';
   my $content  = $in->{content} || '';
   my $mode     = $in->{mode}    || 'write';
   my $bitmask  = $in->{bitmask} || oct 777;
   my $raw_name = $file;
   my $write_fh; # will be the lexical file handle local to this block
   my ( $root, $path, $clean_name, @dirs ) =
      ( '',    '',    '',          ()    );

   ( $root, $path, $file ) = atomize_path( $file );

   $mode = 'trunc' if $mode eq 'truncate';

   # if the call to this method didn't include a filename to which the caller
   # wants us to write, then complain about it
   return $this->_throw(
      'no input',
      {
         meth    => 'write_file',
         missing => 'a file name to create, write, or append',
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

   # if the call to this method didn't include any data which the caller
   # wants us to write or append to the file, then complain about it
   return $this->_throw(
      'no input',
      {
         meth    => 'write_file',
         missing => 'the content you want to write or append',
         opts    => $opts,
      }
   ) if (
      length $content == 0
         &&
      $mode ne 'trunc'
         &&
      !$EMPTY_WRITES_OK
         &&
      !$opts->{'--empty-writes-OK'}
   );

   # check if file already exists in the form of a directory
   return $this->_throw(
      'cant write_file on a dir',
      {
         filename => $raw_name,
         opts     => $opts,
      }
   ) if -d $raw_name;

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
   unless ( $mode eq 'write' || $mode eq 'append' || $mode eq 'trunc' ) {

      return $this->_throw(
         'bad openmode popen',
         {
            meth     => 'write_file',
            filename => $raw_name,
            badmode  => $mode,
            opts     => $opts,
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
         'cant fwrite',
         {
            filename => $clean_name,
            dirname  => $root . $path,
            opts     => $opts,
         }
      ) unless -w $clean_name;
   }
   else {

      # if file doesn't exist, see if we can create it
      return $this->_throw(
         'cant fcreate',
         {
            filename => $clean_name,
            dirname  => $root . $path,
            opts     => $opts,
         }
      ) unless -w $root . $path;
   }

   # if you use the --no-lock option, please consider the risks

   if ( $$opts{'--no-lock'} || !$USE_FLOCK ) {

      # only non-existent files get bitmask arguments
      if ( -e $clean_name ) {

         sysopen
            $write_fh,
            $clean_name,
            $$MODES{sysopen}{ $mode }
         or return $this->_throw(
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
      else {

         sysopen
            $write_fh,
            $clean_name,
            $$MODES{sysopen}{ $mode },
            $bitmask
         or return $this->_throw(
            'bad open',
            {
               filename  => $clean_name,
               mode      => $mode,
               exception => $!,
               cmd       => qq($clean_name, $$MODES{sysopen}{$mode}, $bitmask),
               opts      => $opts,
            }
         );
      }
   }
   else {
      # open read-only first to safely check if we can get a lock.
      if ( -e $clean_name ) {

         open $write_fh, '<', $clean_name or
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
         my $lockstat = $this->_seize( $clean_name, $write_fh );

         return unless $lockstat;

         sysopen
            $write_fh,
            $clean_name,
            $$MODES{sysopen}{ $mode }
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

         sysopen
            $write_fh,
            $clean_name,
            $$MODES{sysopen}{ $mode },
            $bitmask
         or return $this->_throw(
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
         my $lockstat = $this->_seize( $clean_name, $write_fh );

         return unless $lockstat;
      }

      # now truncate
      if ( $mode ne 'append' ) {

         truncate( $write_fh, 0 ) or return $this->_throw(
            'bad systrunc',
            {
               filename  => $clean_name,
               exception => $!,
               opts      => $opts,
            }
         );

      }
   }

   CORE::binmode( $write_fh ) if $in->{binmode} || $opts->{'--binmode'};

   $in->{content} ||= ''; syswrite( $write_fh, $in->{content} );

   # release lock on the file

   $this->_release( $write_fh ) unless $$opts{'--no-lock'} || !$USE_FLOCK;

   close $write_fh or
      return $this->_throw(
         'bad close',
         {
            filename  => $clean_name,
            mode      => $mode,
            exception => $!,
            opts      => $opts,
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
   my $policy = { };

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

   $file = strip_path($file) if $opts->{'--strip-path'};

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
   my $this  = shift @_;
   my $opts  = $this->_remove_opts( \@_ );
   my $in    = $this->_names_values( @_ );
   my $file  = shift @_ ||'';
   my @dirs;
   my $path;

   return $this->_throw(
      'no input',
      {
         meth    => 'touch',
         missing => 'a file name or file handle reference',
         opts    => $opts,
      }
   ) unless defined $file && length $file;

   $path = $this->return_path( $file );

   # see if the file exists already and is a directory
   return $this->_throw(
      'cant touch on a dir',
      {
         filename => $file,
         dirname  => $path || '',
         opts     => $opts,
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
         opts     => $opts,
      }
   ) if ( -e $path && !-r $path );

   $this->make_dir( $path ) unless -e $path;

   # create the file if it doesn't exist (like the *nix touch command does)
   $this->write_file(
      filename => $file,
      content  => '',
      '--empty-writes-OK'
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

   push @ret, 'PLAIN'     if (-f $f);   push @ret, 'TEXT'      if (-T $f);
   push @ret, 'BINARY'    if (-B $f);   push @ret, 'DIRECTORY' if (-d $f);
   push @ret, 'SYMLINK'   if (-l $f);   push @ret, 'PIPE'      if (-p $f);
   push @ret, 'SOCKET'    if (-S $f);   push @ret, 'BLOCK'     if (-b $f);
   push @ret, 'CHARACTER' if (-c $f);

   ## no critic
   push @ret, 'TTY'       if (-t $f);
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
   my $this = shift @_; my $opts = $this->_remove_opts( \@_ );
   my $dir  = shift @_ ||''; my @files = ();
   my $dir_hash = { }; my $dir_list = [];

   return $this->_throw
      (
         'no input',
         {
            'meth'      => 'load_dir',
            'missing'   => 'a directory name',
            'opts'      => $opts,
         }
      )
   unless length $dir;

   @files = $this->list_dir($dir,'--files-only');

   # map the content of each file into a hash key-value element where the
   # key name for each file is the name of the file
   if (!$opts->{'--as-list'} and !$opts->{'--as-listref'}) {

      foreach (@files) {

         $dir_hash->{ $_ } = $this->load_file( $dir . SL . $_ );
      }

      return($dir_hash);
   }
   else {

      foreach (@files) {

         push(@{$dir_list},$this->load_file( $dir . SL . $_ ));
      }

      return($dir_list) if ($opts->{'--as-listref'}); return(@{$dir_list});
   }

   $dir_hash;
}


# --------------------------------------------------------
# File::Util::make_dir()
# --------------------------------------------------------
sub make_dir {
   my $this = shift @_;
   my $opts = $this->_remove_opts( \@_ );
   my( $dir, $bitmask ) = @_;

   $bitmask ||= oct 777;

   if ( $$opts{'--if-not-exists'} ) {

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
   my $file     = $in->{file} || $in->{filename} || '';
   my $mode     = $in->{mode} || 'write';
   my $bitmask  = $in->{bitmask} || oct 777;
   my $raw_name = $file;
   my $fh; # will be the lexical file handle scoped to this method
   my ( $root, $path, $clean_name, @dirs ) =
      ( '',    '',    '',          ()    );

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
      !exists $opts->{'--use-sysopen'} &&
      !defined $opts->{'--use-sysopen'}
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

   if ( $$opts{'--no-lock'} || !$USE_FLOCK ) {
      if (
         !exists $opts->{'--use-sysopen'} &&
         !defined $opts->{'--use-sysopen'}
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
         !exists $opts->{'--use-sysopen'} &&
         !defined $opts->{'--use-sysopen'}
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
   CORE::binmode( $fh ) if $in->{binmode} || $opts->{'--binmode'};

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
sub trunc { $_[0]->write_file( mode => 'trunc', file => $_[1]) }


# --------------------------------------------------------
# File::Util::use_flock()
# --------------------------------------------------------
sub use_flock {
   my $arg = _myargs( @_ );

   if (defined($arg)) { $USE_FLOCK = $arg }

   $USE_FLOCK
}


=pod

=head1 NAME

File::Util - Easy, versatile, portable file handling

=head1 DESCRIPTION

File::Util provides a comprehensive toolbox of utilities to automate all
kinds of common tasks on file / directories.  Its purpose is to do so
in the most portable manner possible so that users of this module won't
have to worry about whether their programs will work on other OSes
and machines.

=head1 SYNOPSIS

   use File::Util;
   my $f = File::Util->new();

   my $content = $f->load_file('foo.txt');

   $content =~ s/this/that/g;

   $f->write_file(
      file => 'bar.txt',
      content => $content,
      bitmask => 0644
   );

   $f->write_file(
      file => 'file.bin', content => $binary_content, '--binmode'
   );

   my @lines = $f->load_file('randomquote.txt', '--as-lines');
   my $line  = int rand scalar @lines;

   print $lines[ $line ];

   my @files = $f->list_dir('/var/tmp', qw/ --files-only --recurse /);
   my @textfiles = $f->list_dir('/var/tmp', '--pattern=\.txt$');

   if ( $f->can_write('wibble.log') ) {

      my $HANDLE = $f->open_handle(
         file => 'wibble.log',
         mode => 'append'
      );

      print $HANDLE "Hello World! It's ", scalar localtime;

      close $HANDLE
   }

   my $log_line_count = $f->line_count('/var/log/httpd/access_log');

   print "My file has a bitmask of " . $f->bitmask('my.file');

   print "My file is a " . join(', ', $f->file_type('my.file')) . " file."

   warn 'This file is binary!' if $f->isbin('my.file');

   print "My file was last modified on " .
      scalar localtime $f->last_modified('my.file');

   # ...and _lots_ more

=head1 INSTALLATION

To install this module type the following at the command prompt:

   perl Build.PL
   perl Build
   perl Build test
   sudo perl Build install

On Windows systems, the "sudo" part of the command may be omitted, but you
will need to run the rest of the install command with Administrative privileges

=head1 ISA

=over

=item L<Exporter>

=back

=head1 EXPORTED SYMBOLS

Exports nothing by default.  File::Util respects your namespace.

=head2 EXPORT_OK

The following symbols comprise C<@File::Util::EXPORT_OK>), and as such are
available for import to your namespace only upon request.

C<atomize_path>       I<(see L<atomize_path|/atomize_path>)>

C<bitmask>            I<(see L<bitmask|/bitmask>)>

C<can_flock>          I<(see L<can_flock|/can_flock>)>

C<can_read>           I<(see L<can_read|/can_read>)>

C<can_write>          I<(see L<can_write|/can_write>)>

C<created>            I<(see L<created|/created>)>

C<ebcdic>             I<(see L<ebcdic|/ebcdic>)>

C<escape_filename>    I<(see L<escape_filename|/escape_filename>)>

C<existent>           I<(see L<existent|/existent>)>

C<file_type>          I<(see L<file_type|/file_type>)>

C<isbin>              I<(see L<isbin|/isbin>)>

C<last_access>        I<(see L<last_access|/last_access>)>

C<last_changed>       I<(see L<last_changed|/last_changed>)>

C<last_modified>      I<(see L<last_modified|/last_modified>)>

C<NL>                 I<(see L<NL|/NL>)>

C<needs_binmode>      I<(see L<needs_binmode|/needs_binmode>)>

C<return_path>        I<(see L<return_path|/return_path>)>

C<size>               I<(see L<size|/size>)>

C<SL>                 I<(see L<SL|/SL>)>

C<strip_path>         I<(see L<strip_path|/strip_path>)>

C<valid_filename>     I<(see L<valid_filename|/valid_filename>)>

B<Note:> Symbols in C<@L<Class::OOorNO|Class::OOorNO>::EXPORT_OK> are also
available for import.

=head2 EXPORT_TAGS

   :all (exports all of @File::Util::EXPORT_OK)

=head1 METHODS

B<Note:> In the past, some of the methods listed would state that they were
autoloaded methods.  This mechanism has been changed.  Only the error handling
and help messages are AutoLoad'ed now.  I<(see L<AutoLoader>.)> if you want
to know more about AutoLoading in Perl.  See the CHANGES file distributed
with File::Util for an explanation of why this change was made.

Methods listed in alphabetical order.

=head2 C<atomize_path>

=over

=item I<Syntax:> C<atomize_path( [file/path or file_name] )>

This method is used internally by File::Util to portably handle absolute
filenames on different platforms, but it can be a useful tool for you as well.

This method takes a single string as its argument.  The string is expected
to be a fully-qualified (absolute) or relative path to a file or directory.
It carefully splits the string into three parts: The root of the path, the
rest of the path, and the final file/directory named in the string.

Depending on the input, the root and/or path may be empty strings.  The
following table can serve as a guide in what to expect from C<atomize_path()>

   +-------------------------+----------+--------------------+----------------+
   |  INPUT                  |   ROOT   |   PATH-COMPONENT   |   FILE/DIR     |
   +-------------------------+----------+--------------------+----------------+
   |  C:\foo\bar\baz.txt     |   C:\    |   foo\bar          |   baz.txt      |
   |  /foo/bar/baz.txt       |   /      |   foo/bar          |   baz.txt      |
   |  ./a/b/c/d/e/f/g.txt    |          |   ./a/b/c/d/e/f    |   g.txt        |
   |  :a:b:c:d:e:f:g.txt     |   :      |   a:b:c:d:e:f      |   g.txt        |
   |  ../wibble/wombat.ini   |          |   ../wibble        |   wombat.ini   |
   |  ..\woot\noot.doc       |          |   ..\woot          |   noot.doc     |
   |  ../../zoot.conf        |          |   ../..            |   zoot.conf    |
   |  /root                  |   /      |                    |   root         |
   |  /etc/sudoers           |   /      |   etc              |   sudoers      |
   |  /                      |   /      |                    |                |
   |  D:\                    |   D:\    |                    |                |
   |  D:\autorun.inf         |   D:\    |                    |   autorun.inf  |
   +-------------------------+----------+--------------------+----------------+

=back

=head2 C<bitmask>

=over

=item I<Syntax:> C<bitmask( [file name] )>

Gets the bitmask of the named file, provided the file exists. If the file
exists, the bitmask of the named file is returned in four digit octal
notation e.g.- C<0644>.  Otherwise, returns C<undef> if the file does I<not>
exist.

=back

=head2 C<can_flock>

=over

=item I<Syntax:> C<can_flock>

Returns 1 if the current system claims to support C<flock()> I<and> if the
Perl process can successfully call it.  I<(see L<perlfunc/flock>.)>  Unless
both of these conditions are true a zero value (0) is returned.  This is a
constant method.  It accepts no arguments and will always return the same
value for the system on which it is executed.

B<Note:> Perl will try to support or emulate flock whenever it can via
available system calls, namely C<flock>; C<lockf>; or with C<fcntl>.

=back

=head2 C<can_read>

=over

=item I<Syntax:> C<can_read( [file name] )>

Returns 1 if the named file (or directory) is B<readable> by your program
according to the applied permissions of the file system on which the file
resides.  Otherwise a value of undef is returned.

This works the same as Perl's built-in C<-r> file test operator,
I<(see L<perlfunc/-X>)>, it's just easier for some people to remember.

=back

=head2 C<can_write>

=over

=item I<Syntax:> C<can_write( [file name] )>

Returns 1 if the named file (or directory) is B<writable> by your program
according to the applied permissions of the file system on which the file
resides.  Otherwise a value of undef is returned.

This works the same as Perl's built-in C<-w> file test operator,
I<(see L<perlfunc/-X>)>, it's just easier for some people to remember.

=back

=head2 C<created>

=over

=item I<Syntax:> C<created( [file name] )>

Returns the time of creation for the named file in non-leap seconds since
whatever your system considers to be the epoch.  Suitable for feeding to
Perl's built-in functions "gmtime" and "localtime".  I<(see L<perlfunc/time>.)>

=back

=head2 C<ebcdic>

=over

=item I<Syntax:> C<ebcdic>

Returns 1 if the machine on which the code is running uses EBCDIC, or returns
0 if not.  I<(see L<perlebcdic>.)>  This is a constant method.  It accepts
no arguments and will always return the same value for the system on which it
is executed.

=back

=head2 C<escape_filename>

=over

=item I<Syntax:> C<escape_filename( [string], [escape char] )>

Returns it's argument in an escaped form that is suitable for use as a filename.
Illegal characters (i.e.- any type of newline character, tab, vtab, and the
following C<< / | * " ? < : > \ >>), are replaced with [escape char] or
"B<_>" if no [escape char] is specified.  Returns an empty string if no
arguments are provided.

=back

=head2 C<existent>

=over

=item I<Syntax:> C<existent( [file name] )>

Returns 1 if the named file (or directory) exists.  Otherwise a value of
undef is returned.

This works the same as Perl's built-in C<-e> file test operator,
I<(see L<perlfunc/-X>)>, it's just easier for some people to remember.

=back

=head2 C<file_type>

=over

=item I<Syntax:> C<file_type( [file name] )>

Returns a list of keywords corresponding to each of Perl's built in file tests
(those specific to file types) for which the named file returns true.
I<(see L<perlfunc/-X>.)>

The keywords and their definitions appear below; the order of keywords returned
is the same as the order in which the are listed here:

=over

=item C<PLAIN             File is a plain file.>

=item C<TEXT              File is a text file.>

=item C<BINARY            File is a binary file.>

=item C<DIRECTORY         File is a directory.>

=item C<SYMLINK           File is a symbolic link.>

=item C<PIPE              File is a named pipe (FIFO).>

=item C<SOCKET            File is a socket.>

=item C<BLOCK             File is a block special file.>

=item C<CHARACTER         File is a character special file.>

=back

=back

=head2 C<flock_rules>

=over

=item I<Syntax:> C<flock_rules( [keyword list] )>

Sets I/O race condition policy, or tells File::Util how it should handle race
conditions created when a file can't be locked because it is already locked
somewhere else (usually by another process).

An empty call to this method returns a list of keywords representing the rules
that are currently in effect for the object.

Otherwise, a call should include a list with array containing your chosen
directive keywords in order of precedence.  The rules will be applied in
cascading order when a File::Util object attempts to lock a file, so if the
actions specified by the first rule don't result in success, the second rule
is applied, and so on.

Recognized keywords:

=over

=item C<NOBLOCKEX>

tries to get an exclusive lock on the file without blocking (waiting)

=item C<NOBLOCKSH>

tries to get a shared lock on the file without blocking

=item C<BLOCKEX>

waits to try getting an exclusive lock

=item C<BLOCKSH>

waits to try getting a shared lock

=item C<FAIL>

dies with stack trace

=item C<WARN>

warn()s about the error with a stack trace and returns undef

=item C<IGNORE>

ignores the failure to get an exclusive lock

=item C<UNDEF>

returns undef

=item C<ZERO>

returns 0

=back

Examples:

=over

=item ex- C<flock_rules( qw/ NOBLOCKEX FAIL / );>

This is the default policy.  When in effect, the File::Util object will first
attempt to get a non-blocking exclusive lock on the file.  If that attempt
fails the File::Util object will call die() with a detailed error message and
a stack trace.

=item ex- C<flock_rules( qw/ NOBLOCKEX BLOCKEX FAIL / );>

The File::Util object will first attempt to get a non-blocking exclusive lock
on the file.  If that attempt fails it falls back to the second policy rule
"BLOCKEX" and tries again to get an exclusive lock on the file, but this time
by blocking (waiting for its turn).  If that second attempt fails, the
File::Util object will fail with a detailed error message and a stack trace.

=item ex- C<flock_rules( qw/ BLOCKEX IGNORE / );>

The File::Util object will first attempt to get a file non-blocking lock on
the file.  If that attempt fails it will ignore the error, and go on to open
the file anyway and no failures will occur or warings be issued.

=back

=back

=head2 C<isbin>

=over

=item I<Syntax:> C<isbin( [file name] )>

Returns 1 if the named file (or directory) exists.  Otherwise a value of undef
is returned, indicating that the named file either does not exist or is of
another file type.

This works the same as Perl's built-in C<-B> file test operator,
I<(see L<perlfunc/-X>)>, it's just easier for some people to remember.

=back

=head2 C<last_access>

=over

=item I<Syntax:> C<last_access( [file name] )>

Returns the last accessed time for the named file in non-leap seconds since
whatever your system considers to be the epoch.  Suitable for feeding to
Perl's built-in functions "gmtime" and "localtime".  I<(see L<perlfunc/time>.)>

=back

=head2 C<last_changed>

=over

=item I<Syntax:> C<last_changed( [file name] )>

Returns the inode change time for the named file in non-leap seconds since
whatever your system considers to be the epoch.  Suitable for feeding to
Perl's built-in functions "gmtime" and "localtime".  I<(see L<perlfunc/time>.)>

=back

=head2 C<last_modified>

=over

=item I<Syntax:> C<last_modified( [file name] )>

Returns the last modified time for the named file in non-leap seconds since
whatever your system considers to be the epoch.  Suitable for feeding to
Perl's built-in functions "gmtime" and "localtime".  I<(see L<perlfunc/time>.)>

=back

=head2 C<line_count>

=over

=item I<Syntax:> C<line_count( [file name] )>

Returns the number of lines in the named file.  Fails with an error if the
named file does not exist.

=back

=head2 C<list_dir>

=over

=item I<Syntax:> C<list_dir( [directory name] , [--opts] )>

Returns alphabetically sorted all file names in the directory specified if it
exists.  Fails with an error message if no such directory is found, or the
directory is inaccessible.

The behavior of this method has changed slightly after version 3.29.  If running
with the C<--fatals-as-warning> flag, the previous behavior was to abort
immediately.  This is not the case anymore.  If running with the
C<--fatals-as-warning> flag, C<list_dir()> will still emit a warning when it
encounters an otherwise fatal error, but it will also return whatever directory
contents it is able to successfully access.

=over

=item B<Flags accepted by C<list_dir()>>

=over

=item C<--dirs-only>

return only directory contents which are directories

=item C<--files-only>

return only directory contents which are files

=item C<--no-fsdots>

do not include "." and ".." in the list of directory contents

=item C<--pattern>

return only files/directories matching pattern provided. argument
should be plain text string.  It will be converted to a perl regex and passed
to CORE::grep as the method scans through directory listings for a match.

(ex- C<'--pattern=\.txt$'> returns all file/directory names ending in ".txt".
It will match "foo.txt", but not "foo.txt.gz" because of the "$" anchor in the
regular expression passed in.)

or for the opposite effect, C<< '--pattern=.*(?<!\.txt)$' >> returns all
file/directory names that don't end in ".txt"

=item C<--with-paths>

Include file paths with the contents of the directory list, relative
to the directory named in the call.

=item C<--recurse>

Recurse subdirectories

=item C<--follow>

Recurse subdirectories, same as C<--recurse>

=item C<--dirs-as-ref>

When returning directory listing, include first a reference to the list
of subdirectories found, followed by anything else returned by the call.

=item C<--files-as-ref>

When returning directory listing, include last a reference to the list
of files found, preceded by a list of subdirectories found (or preceded
by a list reference to subdirectories found if C<--dirs-as-ref> was also used).

=item C<--as-ref>

Return a pair list references: the first is a reference to any subdirectories
found by the call, the second is a reference to any files found by the call.

=item C<--sl-after-dirs>

Append a directory separator ("/, "\", or ":" depending on your system)
to all directories found by the call.  Useful in visual displays for quick
differentiation between subdirectories and files.

=item C<--ignore-case>

Items returned by the call to this method are sorted alphabetically by
default, so "Zoo.txt" comes before "alligator.txt" because the alphabetical
sort is case-sensitive.  This is also the way directories are listed at the
system level on most operating systems.

If you'd like the directory contents returned by this method to be
sorted without regard to case , use this flag.

=item C<--count-only>

Returns a single value: an integer reflecting the number of items
found in the directory after applying the filter criteria specified by any
other flags (ie- "--dirs-only", "--recurse", etc.) that may have been passed
in as well.

=back

=back

=back

=head2 C<load_dir>

=over

=item I<Syntax:> C<load_dir( [directory name] , [--ds-type] )>

Returns a data structure containing the contents of each file present in the
named directory.

The type of data structure returned is determined by the optional data-type
switch.  Only one option may be used for a given call to this method.
Recognized options are listed below.

=over

=item B<Flags accepted by C<load_dir()>>

=over

=item C<--as-list>

Causes the method to return a list comprised of the contents loaded from
each file (in case-sensitive order) located in the named directory.

=item C<--as-listref>

Same as above, except an array reference to the list of items is returned
rather than the list itself.

=item C<--as-hashref> *(default)

Implicit.  If no option is passed in, the default behavior is to return a
reference to an anonymous hash whose keys are the names of each file in the
specified directory; the hash values for contain the contents of the file
represented by its corresponding key.

=back

=back

B<Note:> This method does not distinguish between plain files and other file
types such as binaries, FIFOs, sockets, etc.

Restrictions imposed by the current "read limit"
I<(see the L<readlimit()|/readlimit>) entry below> will be applied to the
files opened by this method as well.  Adjust the readlimit as necessary.

   my $files = $fu->load_dir('directory/to/load/');

The above code creates an anonymous hash reference that is stored in the
variable named "C<$files>".  The keys and values of the hash referenced by
"C<$files>" would resemble those of the following code snippet (given that
the files in the named directory were the files 'a.txt', 'b.html', 'c.dat',
and 'd.conf')

   my($files) =
      {
         'a.txt'  => "the contents of file a.txt",
         'b.html' => "the contents of file b.html",
         'c.dat'  => "the contents of file c.dat",
         'd.conf' => "the contents of file d.conf",
      };

=back

=head2 C<load_file>

=over

=item I<Syntax:> C<load_file( [file name] , [--opts] )>

=item I<OR:> C<< load_file( 'FH' => [file handle reference] , [--opts] ) >>

If [file name] is passed, returns the contents of [file name] in a string.
If a [file handle reference] is passed instead, the filehandle will be
C<CORE::read()> and the data obtained by the read will be returned in a string.

If you desire the contents of the file (or file handle data) in a list of
lines instead of a single string, this can be accomplished through the use
of the C<--as-lines> flag (see below).

=over

=item B<Flags accepted by C<load_file()>>

=over

=item C<--as-lines>

If this flag is passed then your call to C<load_file> will return an ordered
list of strings, each of which is a line from the file [file name].  The lines
are returned in the order they are read, from the beginning of the file to the
end.

This is not the default behavior.  The default behavior is for C<load_file> to
return a single string containing the entire contents of the file, including
line break characters.

=item C<--no-lock>

By default this method will attempt to get a lock on the file while it is
being read, following whatever rules are in place for the flock policy
established either by default (implicitly) or changed by you in a call to
File::Util::flock_rules()
I<(see the L<flock_rules()|/flock_rules>) entry below>.

This method will not try to get a lock on the file if the File::Util object was
created with the option C<--no-lock> or if the method was called with the
option C<--no-lock>.

This method will automatically call binmode() on binary files for you.  If you
pass in a filehandle instead of a file name you do not get this automatic
check performed for you.  In such a case, you'll have to call binmode() on
the filehandle yourself.  Once you pass a filehandle to this method it has no
way of telling if the file opened to that filehandle is binary or not.

B<Notes:> This method does not distinguish between plain files and other file
types such as binaries, FIFOs, sockets, etc.

Restrictions imposed by the current "read limit"
I<(see the L<readlimit()|/readlimit>) entry below> will be applied to the
files opened by this method as well.  Adjust the readlimit as necessary.

=back

=back

=back

=head2 C<make_dir>

=over

=item I<Syntax:> C<make_dir( [new directory name] , [bitmask], [--opts] )>

Attempts to create (recursively) a directory as [new directory name] with
the [bitmask] provided.  The bitmask is an optional argument and defaults to
0777, combined with the user's current umask.  If specified, the bitmask
must be supplied in the form required by the native perl umask function.
I<see L<perlfunc/"umask">> for more information about the format of the
bitmask argument.

As mentioned above, the recursive creation of directories is transparently
handled for you.  This means that if the name of the directory you pass in
contains a parent directory that does not exist, the parent directory(ies) will
be created for you automatically and silently in order to create the final
directory in the [new directory name].

Simply put, if [new directory] is "/path/to/directory" and the directory
"/path/to" does not exist, the directory "/path/to" will be created and the
"/path/to/directory" directory will be created thereafter.  All directories
created will be created with the [bitmask] you specify, or with the default
of 0777.

Upon successful creation of the [new directory name], the [new directory name]
is returned to the caller.

=over

=item B<Flags accepted by C<make_dir()>>

=over

=item C<--if-not-exists>

If this flag is passed in then make_dir will not attempt to create the directory
if it already exists.  Rather it will return the name of the directory as it
normally would if the directory did not exist previous to calling this method.

If a call to this method is made without the C<--if-not-exists> flag and the
directory specified as [new directory name] does in fact exist, an error will
result as it is impossible to create a directory that already exists.

=back

=back

=back

=head2 C<max_dives>

=over

=item I<Syntax:> C<max_dives( [integer] )>

When called without any arguments, this method returns an integer reflecting
the current number of times the File::Util object will dive into the
subdirectories it discovers when recursively listing directory contents from
a call to C<File::Util::list_dir()>.  The default is 1000.  If the number is
exceeded, the File::Util object will fail with a diagnostic error message.

When called with an argument, it sets the maximum number of times a File::Util
object will recurse into subdirectories before failing with an error message.

This method can only be called with a numeric integer value.  Passing a bad
argument to this method will cause it to fail with an error message.

I<(see L<list_dir|/list_dir>)>

=back

=head2 C<needs_binmode>

=over

=item I<Syntax:> C<needs_binmode>

Returns 1 if the machine on which the code is running requires that C<binmode()>
I<(a built-in function)> be called on open file handles, or returns 0 if not.
I<(see L<perlfunc/binmode>.)>  This is a constant method.  It accepts no
arguments and will always return the same value for the system on which it
is executed.

=back

=head2 C<new>

=over

=item I<Syntax:> C<< new( ['parameters' => 'values', etc], [--flags] ) >>

This is the File::Util constructor method.  eg- It returns a new File::Util
object reference when you call it.  It recognizes various parameters and flags
that govern the behavior of the new File::Util object.

=over

=item B<Parameters accepted by C<new()>>

=over

=item use_flock   => true/false value

Optionally specify this option to the C<File::Util::new> method instruct the
new object that it should never attempt to use C<flock()> in it's I/O
operations.  The default is to use C<flock()> when available on your system.
Specify this option with a true or false value, true to use C<flock()>, false
to not use it.

=item readlimit   => positive integer

Optionally specify this option to the File::Util::new method to instruct the
new object that it should never attempt to open and read in a file greater
than the number of bytes you specify.  Obviously this argument can only be
a numeric integer value, otherwise it will be silently ignored.  The default
readlimit for File::Util objects is 52428800 bytes (50 megabytes).

=item max_dives   => positive integer

Optionally specify this option to the File::Util::new method to instruct the
new object to set the maximum number of times it will recurse into
subdirectories while performing directory listing operations before failing
with an error message.  This argument can only be a numeric integer value,
otherwise it will be silently ignored.

=back

=item B<Flags accepted by C<new()>>

=over

=item C<--fatals-as-warning>

Directive to instruct the new File::Util object that when any call to one of
its methods results in a fatal error that it should return B<C<undef>>
instead of the value(s) that would normally be returned by the call, and to
send an error message to STDERR as well.

=item C<--fatals-as-status>

Directive to instruct the new File::Util object that when any call to one of
its methods results in a fatal error that it should return B<C<undef>>
instead of the value(s) that would normally be returned by the call.

=item C<--fatals-as-errmsg>

Directive to instruct the new File::Util object that when any call to one of
its methods results in a fatal error that it should return B<an error message>
instead of the value(s) that would normally be returned by the call.

=back

=back

=back

=head2 C<open_handle>

=over

=item I<Syntax:> C<< open_handle( file => [file name], [--opts] ) >>

=item I<OR:> C<< open_handle( file => [file name], mode => [mode], [--opts] ) >>

=item I<OR:> C<< open_handle( file => [file name], mode => [mode], bitmask => [bitmask], [--opts] ) >>

=item I<OR:> C<< open_handle( file => [file name], mode => [mode], bitmask => [bitmask], dbitmask => [bitmask], [--opts] ) >>

Attempts to get a unique open file handle on [file name] in [mode] mode.
Returns the file handle if successful or generates a fatal error with a
diagnostic message if the operation fails.

You will need to remember to call C<close()> on the filehandle yourself, at
your own discretion.  Leaving filehandles open is not a good practice, and
is not recommended.  I<see L<perlfunc/close>>).

Once you have the file handle you would use it as you would use any file handle.
Remember that unless you specifically turn file locking off when the
C<File::Util> object is created (see I<(see L<new|/new>)> or by using the
C<--no-lock> flag when calling C<open_handle>, that file locking is going to
automagically be handled for you behind the scenes, so long as your OS supports
file locking of any kind at all.  Great!  It's very convenient for you to not
have to worry about portably taking care of file locking between one
application and the next; by using C<File::Util> in all of them, you know
that you're covered.

A slight inconvenience for the price of a larger set of features (compare
L<write_file|/write_file> to this method)
I<B<you will have to release the file lock on the open handle yourself.>>
C<File::Util> can't manage it for you anymore once it hands the handle over
to you.  At that point, it's all yours.  In order to release the file lock
on your file handle, call L<unlock_open_handle()|/unlock_open_handle> on it.
Otherwise the lock will remain for the life of your process.  If you don't
want to use the free portable file locking, remember the C<--no-lock> flag,
which will turn off file locking for your open handle.  Seldom, however, should
you ever opt to not use file locking unless you really know what you are doing.

If the file does not yet exist it will be created, and it will be created
with a bitmask of [bitmask] if you specify a file creation bitmask using
the C<'bitmask'> option, otherwise the file will be created with the default
bitmask of 0777.  The bitmask is combined with the user's current umask,
whether you specify a value or not.  This is a function of Perl,
not File::Util.

If specified, the bitmask must be supplied in the form required by the
native perl umask function.  I<see L<perlfunc/"umask">> for more information
about the format of the bitmask argument.  If the file [file name] already
exists then the bitmask argument has no effect and is silently ignored.

Any non-existent directories in the path preceding the actual file name will
be automatically (and silently - no warnings) created for you and any new
directories will be created with a bitmask of [dbitmask], provided you specify
a directory creation bitmask with the C<'dbitmask'> option.

If specified, the directory creation bitmask [dbitmask] must be supplied in
the form required by the native perl umask function.

If there is an error while trying to create any preceding directories, the
failure results in a fatal error with a diagnostic error message.  If all
directories preceding the name of the file already exist, the dbitmask
argument has no effect and is silently ignored.

=back

=over

=item B<Native Perl open modes>

The default behavior of C<open_handle()> is to open file handles using Perl's
native C<open()> I<(see L<perlfunc/open>)>.  Unless you use the
C<--use-sysopen> flag, the following modes and only these modes are valid.

=over

=item C<< 'mode' => 'read' >>

[file name] is opened in read-only mode.  If the file does not yet exist then
a fatal error will occur with a diagnostic help message to help you troubleshoot
the problem.

=item C<< 'mode' => 'write' >> (this is the default mode)

[file name] is created if it does not yet exist.  If [file name] already exists
then its contents are overwritten with the new content provided.

=item C<< 'mode' => 'append' >>

[file name] is created if it does not yet exist.  If [file name] already exists
its contents will be preserved and the new content you provide will be appended
to the end of the file.

=back

=back

=over

=item B<System level open modes ("open a la C")>

Optionally you can ask C<File::Util> to open your handle using C<CORE::sysopen>
instead of using the native Perl C<CORE::open()>.  This is accomplished by
passing in the C<--use-sysopen> flag.  Using this feature opens up more
possibilities as far as the open modes you can choose from, but also carries
with it a few caveats so you have to be careful, just as you'd have to be a
little more careful when using C<sysopen()> anyway.

Specifically you need to remember that when using this feature you must NOT
mix different types of I/O when working with the file handle.  You can't go
opening file handles with C<sysopen()> and print to them as you normally
would print to a file handle.  You have to use C<syswrite()> instead.  The
same applies here.  If you get a C<sysopen()>'d filehandle from C<open_handle()>
it is imperative that you use C<syswrite()> on it.  You'll also need to use
C<sysseek()> and other type of C<sys>* commands on the filehandle instead of
their native Perl equivalents.

(see L<perlfunc/sysopen>, L<perlfunc/syswrite>, L<perlfunc/sysseek>,
L<perlfunc/sysread>)

That said, here are the different modes you can choose from to get a file handle
when using the C<--use-sysopen> flag.  Remember that these won't work unless
you use the flag, and will generate an error if you try using them without it.
The standard C<'read'>, C<'write'>, and C<'append'> modes are already available
to you by default.  These are the extended modes:

=over

=item C<< 'mode' => 'rwcreate' >>

[file name] is opened in read-write mode, and will be created for you if it
does not already exist.

=item C<< 'mode' => 'rwupdate' >>

[file name] is opened for you in read-write mode, but must already exist.  If
it does not exist, a fatal error will result and a diagnostic help message will
be printed out to help you troubleshoot the problem.

=item C<< 'mode' => 'rwclobber' >>

[file name] is opened for you in read-write mode.  If the file already exists
it's contents will be "clobbered" or wiped out.  The file will then be empty
and you will be working with the then-truncated file.  This can not be undone.
Once you call C<open_handle()> using this option, your file WILL be wiped out.
If the file does not exist yet, it will be created for you.

=item C<< 'mode' => 'rwappend' >>

[file name] will be opened for you in read-write mode ready for appending.  The
file's contents will not be wiped out; they will be preserved and you will be
working in append fashion.  You will only be able to write starting at the end
of the file.  If the file does not exist, it will be created for you.

=back

Remember to use C<sysread()> and not plain C<read()> when reading those
C<sysopen()>'d filehandles!

=back

=over

=item B<Flags accepted by C<open_handle()>>

=over

=item C<--binmode>

Makes sure that CORE::binmode() is called on the filehandle when your content
is written.  This is useful for times when the content you are writing to file
is a binary stream. I<(see L<perlfunc/binmode>)>.

=item C<--no-lock>

By default this method will attempt to get a lock on the file while it is
being read, following whatever rules are in place for the flock policy
established either by default (implicitly) or changed by you in a call to
File::Util::flock_rules()
I<(see the L<flock_rules()|/flock_rules>) entry below>.

This method will not try to get a lock on the file if the File::Util object was
created with the option C<--no-lock> or if this method is called with the
option C<--no-lock>.

=item C<--use-sysopen>

Instead of opening the file using Perl's native C<open()> command, C<File::Util>
will open the file with the C<sysopen()> command.  You will have to remember
that your filehandle is a C<sysopen()>'d one, and that you will not be able to
use native Perl I/O functions on it.  You will have to use the C<sys>*
equivalents.  See L<perlopentut> for a more in-depth explanation of why you
can't mix native Perl I/O with system I/O.

=back

=back

=head2 C<readlimit>

=over

=item I<Syntax:> C<readlimit( [integer] )>

By default, the largest size file that File::Util will read into memory and
return via the L<load_file|/load_file> is 52428800 byptes (50 megabytes).

This value can be modified by calling this method with an integer value
reflecting the new limit you want to impose, in bytes.  For example, if you want
to set the limit to 10 megabytes, call the method with an argument of 10485760.

If this method is called without an argument, the read limit currently in force
for the File::Util object will be returned.

=back

=head2 C<return_path>

=over

=item I<Syntax:> C<return_path( [string] )>

Takes the file path from the file name provided and returns it such that
"/foo/bar/baz.txt" is returned "/foo/bar".

=back

=head2 C<size>

=over

=item I<Syntax:> C<size( [file name] )>

Returns the file size of [file name] in bytes.  Returns C<0> if the file is
empty, returns C<undef> if the file does not exist.

=back

=head2 C<strip_path>

=over

=item I<Syntax:> C<strip_path( [string] )>

Strips the file path from the file name provided and returns the file name only.

=back

=head2 C<touch>

=over

=item I<Syntax:> C<touch( [file name] )>

Behaves like the *nix C<touch> command; Updates the access and modification
times of the specified file to the current time.  If the file does not exist,
C<File::Util> tries to create it empty.  This method will fail with a fatal
error if system permissions deny alterations to or creation of the file.

Returns C<1> if successful.  If unsuccessful, fails with a descriptive error
message about what went wrong.

=back

=head2 C<trunc>

=over

=item I<Syntax:> C<trunc( [file name] )>

Truncates [file name] (i.e.- wipes out, or "clobbers" the contents of the
specified file.  Returns C<1> if successful.  If unsuccessful, fails with a
descriptive error message about what went wrong.

=back

=head2 C<unlock_open_handle>

=over

=item I<Syntax:> C<unlock_open_handle([file handle])>

Release the flock on a file handle you opened with L<open_handle|/open_handle>.

Returns true on success, false on failure.  Will not raise a fatal error if
the unlock operation fails.  You can capture the return value from your call
to this method and C<die()> if you so desire.  Failure is not ever very likely,
or C<File::Util> wouldn't have been able to get a portable lock on the file
in the first place.

If C<File::Util> wasn't able to ever lock the file due to limitations of your
operating system, a call to this method will return a true value.

If file locking has been disabled on the file handle via the C<--no-lock> flag
at the time L<open_handle|/open_handle> was called, or if file locking was
disabled using the L<use_flock|/use_flock> method, or if file locking was
disabled on the entire C<File::Util> object at the time of its creation
I<(see L<new()|/new>)>, calling this method will have no effect and a true value
will be returned.

=back

=head2 C<use_flock>

=over

=item I<Syntax:> C<use_flock( [true / false value] )>

When called without any arguments, this method returns a true or false value
to reflect the current use of C<flock()> within the File::Util object.

When called with a true or false value as its single argument, this method
will tell the File::Util object whether or not it should attempt to use
C<flock()> in its I/O operations.  A true value indicates that the File::Util
object will use C<flock()> if available, a false value indicates that it will
not.  The default is to use C<flock()> when available on your system.

=back

=head2 C<write_file>

=over

=item I<Syntax:> C<< write_file( file' => [file name], 'content' => [string], [--opts] ) >>

=item I<OR:> C<< write_file( file => [file name], content => [string], mode => [mode], [--opts] ) >>

=item I<OR:> C<< write_file( file => [file name], content => [string], mode => [mode], bitmask => [bitmask], [--opts] ) >>

=item I<OR:> C<< write_file( file => [file name], content => [string], mode => [mode], bitmask => [bitmask], dbitmask => [bitmask], [--opts] ) >>

Attempts to write [string] to [file name] in mode [mode].  If the file does
not yet exist it will be created, and it will be created with a bitmask of
[bitmask] if you specify a file creation bitmask using the C<'bitmask'> option,
otherwise the file will be created with the default bitmask of 0777.
The bitmask is combined with the user's current umask, whether you specify a
value or not.  This is a function of Perl, not File::Util.

[string] should be a string or a scalar variable containing a string.  The
string can be any type of data, such as a binary stream, or ascii text with
line breaks, etc.  Be sure to pass in the C<--binmode> flag for binary streams.

If specified, the bitmask must be supplied in the form required by the
native perl umask function.  I<see L<perlfunc/"umask">> for more information
about the format of the bitmask argument.  If the file [file name] already
exists then the bitmask argument has no effect and is silently ignored.

Returns 1 if successful or fails (fatal) with an error message if not
successful.

Any non-existent directories in the path preceding the actual file name will
be automatically (and silently - no warnings) created for you and any new
directories will be created with a bitmask of [dbitmask], provided you specify
a directory creation bitmask with the C<'dbitmask'> option.

If specified, the directory creation bitmask [dbitmask] must be supplied in
the form required by the native perl umask function.

If there is an error while trying to create any preceding directories, the
failure results in a fatal error with a diagnostic error message.  If all
directories preceding the name of the file already exist, the dbitmask
argument has no effect and is silently ignored.

=over

=item C<< 'mode' => 'write' >> (this is the default mode)

[file name] is created if it does not yet exist.  If [file name] already exists
then its contents are overwritten with the new content provided.

=item C<< 'mode' => 'append' >>

[file name] is created if it does not yet exist.  If [file name] already exists
its contents will be preserved and the new content you provide will be appended
to the end of the file.

=back

=over

=item B<Flags accepted by C<write_file()>>

=over

=item C<--binmode>

Makes sure that CORE::binmode() is called on the filehandle when your content
is written.  This is useful for times when the content you are writing to file
is a binary stream.

=item C<--empty-writes-OK>

Allows you to call this method without providing a content argument (it lets
you create an empty file without warning you or failing.  Be advised that
if you use this flag, it will have the same effect as truncating a file
that already has content in it (i.e.- it will "clobber" non-empty files)

=item C<--no-lock>

By default this method will attempt to get a lock on the file while it is
being read, following whatever rules are in place for the flock policy
established either by default (implicitly) or changed by you in a call to
File::Util::flock_rules()
I<(see the L<flock_rules()|/flock_rules>) entry below>.

This method will not try to get a lock on the file if the File::Util object was
created with the option C<--no-lock> or if this method is called with the
option C<--no-lock>.

=back

=back

=back

=head2 C<valid_filename>

=over

=item I<Syntax:> C<valid_filename( [string] )>

For the given string, returns 1 if the string is a legal file name for the
system on which the program is running, or returns undef if it is not.  This
method does not test for the validity of file paths!  It tests for the validity
of file names only.  (It is used internally to check beforehand if a file name
is useable when creating new files, but is also a public method available for
external use.)

=back

=head1 CONSTANTS

=head2 C<NL>

=over

=item I<Syntax:> C<NL>

Returns the correct new line character (or character sequence) for the system
on which your program runs.

=back

=head2 C<SL>

=over

=item I<Syntax:> C<SL>

Returns the correct directory path separator for the system on which your
program runs.

=back

=head2 C<OS>

=over

=item I<Syntax:> C<OS>

Returns the File::Util keyword for the operating system FAMILY it detected.  The
keyword for the detected operating system will be one of the following, derived
from the conents of C<$^O>, or if C<$^O> can not be found, from the contents of
C<$Config::Config{osname}> (see native L<Config> library), or if that
doesn't contain a recognizable value, finally falls back to C<UNIX>.

Generally speaking, Linux operating systems are going to be detected as C<UNIX>.
This isn't a bug.  The OS FAMILY to which it belongs uses C<UNIX> style
filesystem conventions and line endings, which are the relevant things to
file handling operations.

=over

=item UNIX

Specifics: OS name =~ /^(?:darwin|bsdos)/i

=item CYGWIN

Specifics: OS name =~ /^cygwin/i

=item WINDOWS

Specifics: OS name =~ /^MSWin/i

=item VMS

Specifics: OS name =~ /^vms/i

=item DOS

Specifics: OS name =~ /^dos/i

=item MACINTOSH

Specifics: OS name =~ /^MacOS/i

=item EPOC

Specifics: OS name =~ /^epoc/i

=item OS2

Specifics: OS name =~ /^os2/i

=back

=back

=head1 PREREQUISITES

=over

=item L<Perl|perl> 5.006 or better

=item L<Exception::Handler>   v1.00_0 or better

=back

=head1 EXAMPLES

Many of these are demonstrated in the standalone scripts that come in the
"examples" directory as part of this distribution.

=head2 Get the names of all files and subdirectories in a directory

   use File::Util;
   my $f = File::Util->new();
   # option --no-fsdots excludes "." and ".." from the list
   my @dirs_and_files = $f->list_dir('/foo', '--no-fsdots');

=head2 Get the names of all files and subdirectories in a directory, recursively

   use File::Util;
   my $f = File::Util->new();
   my @dirs_and_files = $f->list_dir('/foo', '--recurse');

=head2 Get the names of all files (no subdirectories) in a directory

   use File::Util;
   my $f = File::Util->new();
   my @dirs_and_files = $f->list_dir('/foo', '--files-only');

=head2 Get the names of all subdirectories (no files) in a directory

   use File::Util;
   my $f = File::Util->new();
   my @dirs_and_files = $f->list_dir('/foo', '--dirs-only');

=head2 Get the number of files and subdirectories in a directory

   use File::Util;
   my $f = File::Util->new();
   my @dirs_and_files  = $f->list_dir('/foo', qw/--no-fsdots --count-only/);

=head2 Get the names of files and subdirs in a directory as separate array refs

   use File::Util;
   my $f = File::Util->new();
   my( $dirs, $files ) = $f->list_dir('/foo', '--as-ref');

      -OR-
   my( $dirs, $files ) = $f->list_dir('.', qw/--dirs-as-ref --files-as-ref/);

=head2 Get the contents of a file in a string

   use File::Util;
   my $f = File::Util->new();
   my $contents = $f->load_file('filename');

=head2 Get the contents of a file in an array of lines in the file

   use File::Util;
   my $f = File::Util->new();
   my @contents = $f->load_file('filename','--as-lines');

=head2 Get an open file handle for reading

   use File::Util;
   my $f = File::Util->new();
   my $fh = $f->open_handle(
      file => 'new_filename',
      mode => 'read'
   );

=head2 Get an open file handle for writing

   use File::Util;
   my $f = File::Util->new();
   my $fh = $f->open_handle(
      file => 'new_filename',
      mode => 'write'
   );

=head2 Write to a new or existing file

   use File::Util;
   my $content = 'Pathelogically Eclectic Rubbish Lister';
   my $f = File::Util->new();
   $f->write_file( file => 'a new file.txt', content => $content );

   # you can optionally specify a bitmask for a file if it doesn't exist yet.
   # the bitmask is combined with the user's current umask for the creation
   # mode of the file.  (You should usually omit this.)
   $f->write_file(
      file    => 'a new file.txt',
      bitmask => oct 777,
      content => $content
   );

=head2 Append to a new or existing file

   use File::Util;
   my $content = 'Pathelogically Eclectic Rubbish Lister';
   my $f = File::Util->new();
   $f->write_file(
      file => 'a new file.txt',
      mode => 'append',
      content => $content
   );

=head2 Determine if something is a valid file name

   use File::Util qw( valid_filename );

   if (valid_filename("foo?+/bar~@/#baz.txt")) {
      print "file name is valid"
   else {
      print "file name contains illegal characters"
   }

      -OR-
   use File::Util;
   print File::Util->valid_filename("foo?+/bar~@/#baz.txt") ? 'ok' : 'bad';

      -OR-
   use File::Util;
   my $f = File::Util->new();
   print $f->valid_filename("foo?+/bar~@/#baz.txt") ? 'ok' : 'bad';

=head2 Get the number of lines in a file

   use File::Util;
   my $f = File::Util->new();
   my $linecount = $f->line_count('foo.txt');

=head2 Strip the path from a file name

   use File::Util;
   my $f = File::Util->new();

   # On Windows
   #  (prints "hosts")
   my $path = $f->strip_path('C:\WINDOWS\system32\drivers\etc\hosts');

   # On Linux/Unix
   #  (prints "perl")
   print $f->strip_path('/usr/bin/perl');

   # On a Mac
   #  (prints "baz")
   print $f->strip_path('foo:bar:baz');

=head2 Get the path preceding a file name

   use File::Util;
   my $f = File::Util->new();

   # On Windows
   #  (prints "C:\WINDOWS\system32\drivers\etc")
   my $path = $f->return_path('C:\WINDOWS\system32\drivers\etc\hosts');

   # On Linux/Unix
   #  (prints "/usr/bin")
   print $f->return_path('/usr/bin/perl');

   # On a Mac
   #  (prints "foo:bar")
   print $f->return_path('foo:bar:baz');

=head2 Find out if the host system can use flock

   use File::Util qw( can_flock );
   print can_flock;

      -OR-
   print File::Util->can_flock;

      -OR-
   my $f = File::Util->new();
   print $f->can_flock;

=head2 Find out if the host system needs to call binmode on binary files

   use File::Util qw( needs_binmode );
   print needs_binmode;

      -OR-
   use File::Util;
   print File::Util->needs_binmode;

      -OR-
   use File::Util;
   my $f = File::Util->new();
   print $f->needs_binmode;

=head2 Find out if a file can be opened for read (based on file permissions)

   use File::Util;
   my $f = File::Util->new();
   my $is_readable = $f->can_read('foo.txt');

=head2 Find out if a file can be opened for write (based on file permissions)

   use File::Util;
   my $f = File::Util->new();
   my $is_writable = $f->can_write('foo.txt');

=head2 Escape illegal characters in a potential file name (and its path)

   use File::Util;
   my $f = File::Util->new();

   # prints "C__WINDOWS_system32_drivers_etc_hosts"
   print $f->escape_filename('C:\WINDOWS\system32\drivers\etc\hosts');

   # prints "baz)__@^"
   # (strips the file path from the file name, then escapes it
   print $f->escape_filename(
      '/foo/bar/baz)?*@^',
      '--strip-path'
   );

   # prints "_foo_!_@so~me#illegal$_file&(name"
   # (yes, that is a legal filename)
   print $f->escape_filename(q[\foo*!_@so~me#illegal$*file&(name]);

=head2 Find out if the host system uses EBCDIC

   use File::Util qw( ebcdic );
   print ebcdic;

      -OR-
   use File::Util;
   print File::Util->ebcdic;

      -OR-
   use File::Util;
   my $f = File::Util->new();
   print $f->ebcdic;

=head2 Get the type(s) of an existent file

   use File::Util qw( file_type );
   print file_type('foo.exe');

      -OR-
   use File::Util;
   print File::Util->file_type('bar.txt');

      -OR-
   use File::Util;
   my $f = File::Util->new();
   print $f->file_type('/dev/null');

=head2 Get the bitmask of an existent file

   use File::Util qw( bitmask );
   print bitmask('/usr/sbin/sendmail');

      -OR-
   use File::Util;
   print File::Util->bitmask('C:\COMMAND.COM');

      -OR-
   use File::Util;
   my $f = File::Util->new();
   print $f->bitmask('/dev/null');

=head2 Get time of creation for a file

   use File::Util qw( created );
   print scalar localtime created('/usr/bin/exim');

      -OR-
   use File::Util;
   print scalar localtime File::Util->created('C:\COMMAND.COM');

      -OR-
   use File::Util;
   my $f = File::Util->new();
   print scalar localtime $f->created('/bin/less');

=head2 Get the last access time for a file

   use File::Util qw( last_access );
   print scalar localtime last_access('/usr/bin/exim');

      -OR-
   use File::Util;
   print scalar localtime File::Util->last_access('C:\COMMAND.COM');

      -OR-
   use File::Util;
   my $f = File::Util->new();
   print scalar localtime $f->last_access('/bin/less');

=head2 Get the inode change time for a file

   use File::Util qw( last_changed );
   print scalar localtime last_changed('/usr/bin/vim');

      -OR-
   use File::Util;
   print scalar localtime File::Util->last_changed('C:\COMMAND.COM');

      -OR-
   use File::Util;
   my $f = File::Util->new();
   print scalar localtime $f->last_changed('/bin/cpio');

=head2 Get the last modified time for a file

   use File::Util qw( last_modified );
   print scalar localtime last_modified('/usr/bin/exim');

      -OR-
   use File::Util;
   print scalar localtime File::Util->last_modified('C:\COMMAND.COM');

      -OR-
   use File::Util;
   my $f = File::Util->new();
   print scalar localtime $f->last_modified('/bin/less');

=head2 Make a new directory, recursively if neccessary

   use File::Util;
   my $f = File::Util->new();
   $f->make_dir('/var/tmp/tempfiles/foo/bar/');

   # you can optionally specify a bitmask for the new directory.
   # the bitmask is combined with the user's current umask for the creation
   # mode of the directory.  (You should usually omit this.)
   $f->make_dir('/var/tmp/tempfiles/foo/bar/',0755);

=head2 Touch a file

   use File::Util qw( touch );
   touch('somefile.txt');

      -OR-
   use File::Util;
   my $f = File::Util->new();
   $f->touch('/foo/bar/baz.tmp');

=head2 Truncate a file

   use File::Util;
   my $f = File::Util->new();
   $f->trunc('/wibble/wombat/noot.tmp');

=head2 Get the correct path separator for the host system

   use File::Util qw( SL );
   print SL;

      -OR-
   use File::Util;
   print File::Util->SL;

      -OR-
   use File::Util;
   my $f = File::Util->new();
   print $f->SL;

=head2 Get the correct newline character for the host system

   use File::Util qw( NL );
   print NL;

      -OR-
   use File::Util;
   print File::Util->NL;

      -OR-
   use File::Util;
   my $f = File::Util->new();
   print $f->NL;

=head1 EXAMPLES (Full Programs)

These are included in the standalone scripts that come in the
"examples" directory as part of this distribution.

=head2 Batch File Rename

   # This code changes the file suffix of all files in a directory
   # ending in *.log so that they end in *.txt
   #
   # Note - This example is NOT recursive.

   use strict;
   use warnings;
   use vars qw( $dir );

   # Regarding "SL" below: On Win/DOS, it is "\" and on Mac/BSD/Linux it is "/"
   # File::Util will automatically detect this for you.
   use File::Util qw( NL SL );

   my $ftl   = File::Util->new();
   my $dir   = 'some/log/directory';
   my @files = $ftl->list_dir( $dir, '--files-only' );

   foreach my $file ( @files ) {

      # don't change the file suffix unless it is *.log
      next unless $file =~ /log$/;

      my $newname = $file;
         $newname =~ s/\.log$/\.txt/;

      if ( rename $dir . SL . $file, $dir . SL . $newname ) {

         print qq($file -> $newname), NL
      }
      else {

         warn qq(Couldn't rename "$_" to "$newname" - $!)
      }
   }

   exit;

=head2 Recursively remove a directory and all its contents

   # This code removes a directory and everything in it

   use strict;
   use warnings;
   use File::Util qw( NL );

   my $ftl = File::Util->new();
   my $removedir = '/path/to/directory/youwanttodelete';

   my @gonners = $ftl->list_dir( $removedir, '--recurse' );

   # remove directory and everything in it
   @gonners = reverse sort { length $a <=> length $b } @gonners;

   foreach my $gonner ( @gonners, $removedir ) {

      print "Removing $gonner ...", NL;

      -d $gonner ? rmdir $gonner || die $! : unlink $gonner || die $!;
    }

   print 'Done!', NL;

   exit;

=head2 Wrap the lines in a file at 72 columns, then save it

   # This code opens a file, wraps its lines, and saves the file with
   # the newly formatted content

   use strict; # always
   use warnings;

   use File::Util qw( NL );
   use Text::Wrap qw( wrap );

   $Text::Wrap::columns = 72; # wrap text at this many columns

   my $f = File::Util->new();
   my $textfile = 'myreport.txt'; # file to wrap and save

   $f->write_file(
     filename => $textfile,
     content => wrap('', '', $f->load_file($textfile))
   );

   print 'Done.', NL x 2;

=head2 Read and increment a counter file, then save it

   # This code opens a file, reads a number value, increments it,
   # then saves the newly incremented value back to the file

   # For the sake of simplicity, this code assumes:
   #   * the counter file already exist and is writeable
   #   * the counter file has one line, which contains only numbers

   use strict; # always
   use warnings;

   use File::Util;

   my $ftl = File::Util->new();
   my $counterfile = 'counter.txt'; # the counter file needs to already exist

   my $count = $ftl->load_file( $counterfile );

   # convert textual number to in-memory int type, -this will default
   # to a zero if it encounters non-numerical or empty content
   chomp $count;
   $count = int $count;

   print "Count value from file: $count.";

   $count++; # increment the counter value by 1

   # save the incremented count back to the counter file
   $ftl->write_file( filename => $counterfile, content => $count );

   # verify that it worked
   print ' Count is now: ' . $ftl->load_file( $counterfile );

   exit;

=head2 Batch Search & Replace

   # Code does a recursive batch search/replace on the content of all files
   # in a given directory
   #
   # Note - this code skips binary files

   use strict;
   use warnings;
   use File::Util qw( NL SL );

   # will get search pattern from file named below
   use constant SFILE => './sr/searchfor';

   # will get replace pattern from file named below
   use constant RFILE => './sr/replacewith';

   # will perform batch operation in directory named below
   use constant INDIR => '/foo/bar/baz';


   # create new File::Util object, set File::Util to send a warning for
   # fatal errors instead of dying
   my $ftl   = File::Util->new( '--fatals-as-warning' );
   my $rstr  = $ftl->load_file( RFILE );
   my $spat  = quotemeta $ftl->load_file( SFILE ); $spat = qr/$spat/;
   my $gsbt  = 0;
   my @opts  = qw/ --files-only --with-paths --recurse /;
   my @files = $ftl->list_dir( INDIR, @opts );

   for (my $i = 0; $i < @files; ++$i) {

      next if $ftl->isbin( $files[$i] );

      my $sbt = 0; my $file = $ftl->load_file( $files[$i] );

      $file =~ s/$spat/++$sbt;++$gsbt;$rstr/ge;

      $ftl->write_file( file => $files[$i], content => $file );

      print $sbt ? qq($sbt replacements in $files[$i]) . NL : '';
   }

   print NL . <<__DONE__ . NL;
   $gsbt replacements in ${\ scalar @files } files.
   __DONE__

   exit;

=head2 Pretty-Print A Directory Recursively

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

   my $filetree  = { };
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

=head1 BUGS

Send bug reports and patches to the CPAN Bug Tracker for File::Util at
L<https://rt.cpan.org/Dist/Display.html?Name=File%3A%3AUtil>

=head1 RESOURCES

If you want to get help, contact the authors (links below in the AUTHORS section)

I fully endorse L<http://www.perlmonks.org> as an excellent source of help with Perl in general.

=head1 CONTRIBUTING

The project website for File::Util is at L<https://github.com/tommybutler/file-util/wiki>

The git repository for File::Util is on Github at L<https://github.com/tommybutler/file-util>

Clone it at L<git://github.com/tommybutler/file-util.git>

This project was a private endeavor for too long so don't hesitate to pitch
in. I want to say I very much appreciate the emails, bug reports, patches,
and all those who contribute their time and talents as CPAN testers.

=head1 AUTHORS

Tommy Butler L<http://www.atrixnet.com/contact>

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

L<File::Slurp>, L<Path::Class>, L<Exception::Handler>

=cut

# --------------------------------------------------------
# File::Util::DESTROY()
# --------------------------------------------------------
sub DESTROY { }

1;
