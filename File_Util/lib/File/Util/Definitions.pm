use 5.006;
use strict;
use warnings;

package File::Util::Definitions;

use Fcntl qw( :flock );

use vars qw(
   @ISA        @EXPORT_OK  %EXPORT_TAGS
   $OS         $MODES      $READLIMIT    $MAXDIVES
   $USE_FLOCK  @ONLOCKFAIL $ILLEGAL_CHR  $CAN_FLOCK
   $EBCDIC     $DIRSPLIT   $_LOCKS       $NEEDS_BINMODE
   $WINROOT    $ATOMIZER   $SL   $NL     $EMPTY_WRITES_OK
   $FSDOTS     $AUTHORITY  $EBL  $EBR
);

use Exporter;

$AUTHORITY  = 'cpan:TOMMY';
@ISA        = qw( Exporter );
@EXPORT_OK  = qw(
   $OS  OS     $MODES      $READLIMIT    $MAXDIVES
   $USE_FLOCK  @ONLOCKFAIL $ILLEGAL_CHR  $CAN_FLOCK
   $EBCDIC     $DIRSPLIT   $_LOCKS       $NEEDS_BINMODE
   $WINROOT    $ATOMIZER   $SL   $NL     $EMPTY_WRITES_OK
   $FSDOTS     $AUTHORITY   SL    NL     $EBL   $EBR
);

%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

BEGIN {

   # Some OS logic.
   unless ( $OS = $^O ) {
      require Config;
      eval { no warnings 'once'; $OS = $Config::Config{osname} }
   };

      if ( $OS =~ /^darwin/i ) { $OS = 'UNIX'      }
   elsif ( $OS =~ /^cygwin/i ) { $OS = 'CYGWIN'    }
   elsif ( $OS =~ /^MSWin/i  ) { $OS = 'WINDOWS'   }
   elsif ( $OS =~ /^vms/i    ) { $OS = 'VMS'       }
   elsif ( $OS =~ /^bsdos/i  ) { $OS = 'UNIX'      }
   elsif ( $OS =~ /^dos/i    ) { $OS = 'DOS'       }
   elsif ( $OS =~ /^MacOS/i  ) { $OS = 'MACINTOSH' }
   elsif ( $OS =~ /^epoc/    ) { $OS = 'EPOC'      }
   elsif ( $OS =~ /^os2/i    ) { $OS = 'OS2'       }
                          else { $OS = 'UNIX'      }

$EBCDIC = qq[\t] ne qq[\011] ? 1 : 0;
$NEEDS_BINMODE = $OS =~ /WINDOWS|DOS|OS2|MSWin/ ? 1 : 0;
$NL =
   $NEEDS_BINMODE               ? qq[\015\012]
      : $EBCDIC || $OS eq 'VMS' ? qq[\n]
         : $OS eq 'MACINTOSH'   ? qq[\015]
            : qq[\012];
$SL =
   { DOS => '\\', EPOC   => '/', MACINTOSH => ':',
     OS2 => '\\', UNIX   => '/', WINDOWS   => chr(92),
     VMS => '/',  CYGWIN => '/', }->{ $OS } || '/';

$_LOCKS = {};

} BEGIN {
   use constant NL => $NL;
   use constant SL => $SL;
   use constant OS => $OS;
}

$WINROOT     = qr/^(?: [[:alpha:]]{1} ) : (?: \\{1,2} )/x;
$DIRSPLIT    = qr/$WINROOT | [\\:\/]/x;
$ATOMIZER    = qr/
   (^ $DIRSPLIT ){0,1}
   (?: (.*) $DIRSPLIT ){0,1}
   (.*) /x;
$ILLEGAL_CHR = qr/[\/\|\\$NL\r\n\t\013\*\"\?\<\:\>]/;
$FSDOTS      = qr/^\.{1,2}$/;
$READLIMIT   = 52428800; # set readlimit to a default of 50 megabytes
$MAXDIVES    = 1000;     # maximum depth for recursive list_dir calls

{
   local $@;

   eval {
      flock( STDOUT, &Fcntl::LOCK_SH );
      flock( STDOUT, &Fcntl::LOCK_UN );
   };

   $CAN_FLOCK = $@ ? 0 : 1;
}

# try to use file locking, define flock race conditions policy
$USE_FLOCK = 1;
@ONLOCKFAIL = qw( NOBLOCKEX FAIL );

$MODES->{popen} = {
   write     => '>',  trunc    => '>',  rwupdate  => '+<',
   append    => '>>', read     => '<',  rwclobber => '+>',
   rwcreate  => '+>', rwappend => '+>>',
};

$MODES->{sysopen} = {
   read      => &Fcntl::O_RDONLY,
   write     => &Fcntl::O_WRONLY | &Fcntl::O_CREAT,
   append    => &Fcntl::O_WRONLY | &Fcntl::O_APPEND | &Fcntl::O_CREAT,
   trunc     => &Fcntl::O_WRONLY | &Fcntl::O_CREAT  | &Fcntl::O_TRUNC,
   rwcreate  => &Fcntl::O_RDWR   | &Fcntl::O_CREAT,
   rwclobber => &Fcntl::O_RDWR   | &Fcntl::O_TRUNC  | &Fcntl::O_CREAT,
   rwappend  => &Fcntl::O_RDWR   | &Fcntl::O_APPEND | &Fcntl::O_CREAT,
   rwupdate  => &Fcntl::O_RDWR,
};

# --------------------------------------------------------
# %$File::Util::LOCKS
# --------------------------------------------------------
$_LOCKS->{IGNORE}    = sub { $_[2] };
$_LOCKS->{ZERO}      = sub { 0 };
$_LOCKS->{UNDEF}     = sub { };
$_LOCKS->{NOBLOCKEX} = sub {
   return $_[2] if flock( $_[2], &Fcntl::LOCK_EX | &Fcntl::LOCK_NB ); return
};
$_LOCKS->{NOBLOCKSH} = sub {
   return $_[2] if flock( $_[2], &Fcntl::LOCK_SH | &Fcntl::LOCK_NB ); return
};
$_LOCKS->{BLOCKEX}   = sub {
   return $_[2] if flock( $_[2], &Fcntl::LOCK_EX ); return
};
$_LOCKS->{BLOCKSH}   = sub {
   return $_[2] if flock( $_[2], &Fcntl::LOCK_SH ); return
};
$_LOCKS->{WARN} = sub {
   $_[0]->_throw(
      'bad flock',
      {
         filename  => $_[1],
         exception => $!,
      },
      '--as-warning',
   ); return
};
$_LOCKS->{FAIL} = sub {
   $_[0]->_throw(
      'bad flock',
      {
         filename  => $_[1],
         exception => $!,
      },
   ); return 0
};

# (for use in error messages)
( $EBL, $EBR ) = ('( ', ' )'); # error bracket left, error bracket right

sub DESTROY {}
1;