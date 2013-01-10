use 5.006;
use strict;
use warnings;

package File::Util::Exception::Diagnostic;

use lib 'lib';

use File::Util::Definitions qw( :all );

use vars qw(
   @ISA    $AUTHORITY
   @EXPORT_OK  %EXPORT_TAGS
);

use Exporter;

$AUTHORITY  = 'cpan:TOMMY';
@ISA        = qw( Exporter );
@EXPORT_OK  = qw( _errors );

%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );


#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#
# ERROR MESSAGES
#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#
sub _errors {
   my $error_thrown = shift @_;

   # begin long table of helpful diag error messages
   my %error_msg_table = (
# NO SUCH FILE
'no such file' => <<'__bad_open__',
$in->{_pak} can't open
   $EBL$in->{filename}$EBR
because it is inaccessible or does not exist.

Origin:     This is *most likely* due to human error.
Solution:   Cannot diagnose.  A human must investigate the problem.
__bad_open__


# BAD FLOCK RULE POLICY
'bad flock rules' => <<'__bad_lockrules__',
Invalid file locking policy can not be implemented.  $in->{_pak}::flock_rules
does not accept one or more of the policy keywords passed to this method.

   Invalid Policy specified: $EBL@{[
   join ' ', map { '[undef]' unless defined $_ } @{ $in->{all} } ]}$EBR

   flock_rules policy in effect before invalid policy failed:
      $EBL@ONLOCKFAIL$EBR

   Proper flock_rules policy includes one or more of the following recognized
   keywords specified in order of precedence:
      BLOCK         waits to try getting an exclusive lock
      FAIL          dies with stack trace
      WARN          warn()s about the error with a stack trace
      IGNORE        ignores the failure to get an exclusive lock
      UNDEF         returns undef
      ZERO          returns 0

Origin:     This is a human error.
Solution:   A human must fix the programming flaw.
__bad_lockrules__


# CAN'T READ FILE - PERMISSIONS
'cant fread' => <<'__cant_read__',
Permissions conflict.  $in->{_pak} can't read the contents of this file:
   $EBL$in->{filename}$EBR

Due to insufficient permissions, the system has denied Perl the right to
view the contents of this file.  It has a bitmask of: (octal number)
   $EBL@{[ sprintf('%04o',(stat($in->{filename}))[2] & 0777) ]}$EBR

   The directory housing it has a bitmask of: (octal number)
      $EBL@{[ sprintf('%04o',(stat($in->{dirname}))[2] & 0777) ]}$EBR

   Current flock_rules policy:
      $EBL@ONLOCKFAIL$EBR

Origin:     This is *most likely* due to human error.  External system errors
            can occur however, but this doesn't have to do with $in->{_pak}.
Solution:   A human must fix the conflict by adjusting the file permissions
            of directories where a program asks $in->{_pak} to perform I/O.
            Try using Perl's chmod command, or the native system chmod()
            command from a shell.
__cant_read__


# CAN'T READ FILE - NOT EXISTENT
'cant fread not found' => <<'__cant_read__',
File not found.  $in->{_pak} can't read the contents of this file:
   $EBL$in->{filename}$EBR

The file specified does not exist.  It can not be opened or read from.

Origin:     This is *most likely* due to human error.  External system errors
            can occur however, but this doesn't have to do with $in->{_pak}.
Solution:   A human must investigate why the application tried to open a
            non-existent file, and/or why the file is expected to exist and
            is not found.
__cant_read__


# CAN'T CREATE FILE - PERMISSIONS
'cant fcreate' => <<'__cant_write__',
Permissions conflict.  $in->{_pak} can't create this file:
   $EBL$in->{filename}$EBR

$in->{_pak} can't create this file because the system has denied Perl
the right to create files in the parent directory.

   The -e test returns $EBL@{[-e $in->{dirname} ]}$EBR for the directory.
   The -r test returns $EBL@{[-r $in->{dirname} ]}$EBR for the directory.
   The -R test returns $EBL@{[-R $in->{dirname} ]}$EBR for the directory.
   The -w test returns $EBL@{[-w $in->{dirname} ]}$EBR for the directory
   The -W test returns $EBL@{[-w $in->{dirname} ]}$EBR for the directory

   Parent directory: (path may be relative and/or redundant)
      $EBL$in->{dirname}$EBR

   Parent directory has a bitmask of: (octal number)
      $EBL@{[ sprintf('%04o',(stat($in->{dirname}))[2] & 0777) ]}$EBR

   Current flock_rules policy:
      $EBL@ONLOCKFAIL$EBR

Origin:     This is *most likely* due to human error.  External system errors
            can occur however, but this doesn't have to do with $in->{_pak}.
Solution:   A human must fix the conflict by adjusting the file permissions
            of directories where a program asks $in->{_pak} to perform I/O.
            Try using Perl's chmod command, or the native system chmod()
            command from a shell.
__cant_write__


# CAN'T WRITE TO FILE - EXISTS AS DIRECTORY
'cant write_file on a dir' => <<'__bad_writefile__',
$in->{_pak} can't write to the specified file because it already exists
as a directory.
   $EBL$in->{filename}$EBR

Origin:     This is a human error.
Solution:   Resolve naming issue between the existent directory and the file
            you wish to create/write/append.
__bad_writefile__


# CAN'T TOUCH A FILE - EXISTS AS DIRECTORY
'cant touch on a dir' => <<'__bad_touchfile__',
$in->{_pak} can't touch the specified file because it already exists
as a directory.
   $EBL$in->{filename}$EBR

Origin:     This is a human error.
Solution:   Resolve naming issue between the existent directory and the file
            you wish to touch.
__bad_touchfile__


# CAN'T WRITE TO FILE
'cant fwrite' => <<'__cant_write__',
Permissions conflict.  $in->{_pak} can't write to this file:
   $EBL$in->{filename}$EBR

Due to insufficient permissions, the system has denied Perl the right
to modify the contents of this file.  It has a bitmask of: (octal number)
   $EBL@{[ sprintf('%04o',(stat($in->{filename}))[2] & 0777) ]}$EBR

   Parent directory has a bitmask of: (octal number)
      $EBL@{[ sprintf('%04o',(stat($in->{dirname}))[2] & 0777) ]}$EBR

   Current flock_rules policy:
      $EBL@ONLOCKFAIL$EBR

Origin:     This is *most likely* due to human error.  External system errors
            can occur however, but this doesn't have to do with $in->{_pak}.
Solution:   A human must fix the conflict by adjusting the file permissions
            of directories where a program asks $in->{_pak} to perform I/O.
            Try using Perl's chmod command, or the native system chmod()
            command from a shell.
__cant_write__


# BAD OPEN MODE - PERL
'bad openmode popen' => <<'__bad_openmode__',
Illegal mode specified for file open.  $in->{_pak} can't open this file:
   $EBL$in->{filename}$EBR

When calling $in->{_pak}::$in->{meth}() you specified that the file
opened in this I/O operation should be opened in $EBL$in->{badmode}$EBR
but that is not a recognized open mode.

Supported open modes for $in->{_pak}::write_file() are:
   write       - open the file in write mode, creating it if necessary, and
                 overwriting any existing contents of the file.
   append      - open the file in append mode

Supported open modes for $in->{_pak}::open_handle() are the same as above, but
also include the following:
   read        - open the file in read-only mode

   (and if the --use-sysopen flag is used):
   rwcreate    - open the file for update (read+write), creating it if necessary
   rwupdate    - open the file for update (read+write). Causes fatal error if
                 the file doesn't yet exist
   rwappend    - open the file for update in append mode
   rwclobber   - open the file for update, erasing all contents (truncating,
                 i.e- "clobbering" the file first)

Origin:     This is a human error.
Solution:   A human must fix the programming flaw by specifying the desired
            open mode from the list above.
__bad_openmode__


# BAD OPEN MODE - SYSOPEN
'bad openmode sysopen' => <<'__bad_openmode__',
Illegal mode specified for file sysopen.  $in->{_pak} can't sysopen this file:
   $EBL$in->{filename}$EBR

When calling $in->{_pak}::$in->{meth}() you specified that the file
opened in this I/O operation should be sysopen()'d in $EBL$in->{badmode}$EBR
but that is not a recognized open mode.

Supported open modes for $in->{_pak}::write_file() are:
   write       - open the file in write mode, creating it if necessary, and
                 overwriting any existing contents of the file.
   append      - open the file in append mode

Supported open modes for $in->{_pak}::open_handle() are the same as above, but
also include the following:
   read        - open the file in read-only mode

   (and if the --use-sysopen flag is used, as the application JUST did):
   rwcreate    - open the file for update (read+write), creating it if necessary
   rwupdate    - open the file for update (read+write). Causes fatal error if
                 the file doesn't yet exist
   rwappend    - open the file for update in append mode
   rwclobber   - open the file for update, erasing all contents (truncating,
                 i.e- "clobbering" the file first)

Origin:     This is a human error.
Solution:   A human must fix the programming flaw by specifying the desired
            sysopen mode from the list above.
__bad_openmode__


# CAN'T LIST DIRECTORY
'cant dread' => <<'__cant_read__',
Permissions conflict.  $in->{_pak} can't list the contents of this directory:
   $EBL$in->{dirname}$EBR

Due to insufficient permissions, the system has denied Perl the right to
view the contents of this directory.  It has a bitmask of: (octal number)
   $EBL@{[ sprintf('%04o',(stat($in->{dirname}))[2] & 0777) ]}$EBR

Origin:     This is *most likely* due to human error.  External system errors
            can occur however, but this doesn't have to do with $in->{_pak}.
Solution:   A human must fix the conflict by adjusting the file permissions
            of directories where a program asks $in->{_pak} to perform I/O.
            Try using Perl's chmod command, or the native system chmod()
            command from a shell.
__cant_read__


# CAN'T CREATE DIRECTORY - PERMISSIONS
'cant dcreate' => <<'__cant_dcreate__',
Permissions conflict.  $in->{_pak} can't create:
   $EBL$in->{dirname}$EBR

   $in->{_pak} can't create this directory because the system has denied
   Perl the right to create files in the parent directory.

   Parent directory: (path may be relative and/or redundant)
      $EBL$in->{parentd}$EBR

   Parent directory has a bitmask of: (octal number)
      $EBL@{[ sprintf('%04o',(stat($in->{parentd}))[2] & 0777) ]}$EBR

Origin:     This is *most likely* due to human error.  External system errors
            can occur however, but this doesn't have to do with $in->{_pak}.
Solution:   A human must fix the conflict by adjusting the file permissions
            of directories where a program asks $in->{_pak} to perform I/O.
            Try using Perl's chmod command, or the native system chmod()
            command from a shell.
__cant_dcreate__


# CAN'T CREATE DIRECTORY - TARGET EXISTS
'make_dir target exists' => <<'__cant_dcreate__',
make_dir target already exists.
   $EBL$in->{dirname}$EBR

$in->{_pak} can't create the directory you specified because that
directory already exists, with filetype attributes of
@{[join(', ', @{ $in->{filetype} })]} and permissions
set to $EBL@{[ sprintf('%04o',(stat($in->{dirname}))[2] & 0777) ]}$EBR

Origin:     This is *most likely* due to human error.  The program has tried
            to make a directory where a directory already exists.
Solution:   Weaken the requirement somewhat by using the "--if-not-exists"
            flag when calling the make_dir object method.  This option
            will cause $in->{_pak} to ignore attempts to create directories
            that already exist, while still creating the ones that don't.
__cant_dcreate__


# CAN'T OPEN
'bad open' => <<'__bad_open__',
$in->{_pak} can't open this file for $EBL$in->{mode}$EBR:
   $EBL$in->{filename}$EBR

   The system returned this error:
      $EBL$in->{exception}$EBR

   $in->{_pak} used this directive in its attempt to open the file
      $EBL$in->{cmd}$EBR

   Current flock_rules policy:
      $EBL@ONLOCKFAIL$EBR

Origin:     This is *most likely* due to human error.
Solution:   Cannot diagnose.  A Human must investigate the problem.
__bad_open__


# BAD CLOSE
'bad close' => <<'__bad_close__',
$in->{_pak} couldn't close this file after $EBL$in->{mode}$EBR
   $EBL$in->{filename}$EBR

   The system returned this error:
      $EBL$in->{exception}$EBR

   Current flock_rules policy:
      $EBL@ONLOCKFAIL$EBR

Origin:     Could be either human _or_ system error.
Solution:   Cannot diagnose.  A Human must investigate the problem.
__bad_close__


# CAN'T TRUNCATE
'bad systrunc' => <<'__bad_systrunc__',
$in->{_pak} couldn't truncate() on $EBL$in->{filename}$EBR after having
successfully opened the file in write mode.

The system returned this error:
   $EBL$in->{exception}$EBR

Current flock_rules policy:
   $EBL@ONLOCKFAIL$EBR

This is most likely _not_ a human error, but has to do with your system's
support for the C truncate() function.
__bad_systrunc__


# CAN'T GET FLOCK AFTER BLOCKING
'bad flock' => <<'__bad_lock__',
$in->{_pak} can't get a lock on the file
   $EBL$in->{filename}$EBR

The system returned this error:
   $EBL$in->{exception}$EBR

Current flock_rules policy:
   $EBL@ONLOCKFAIL$EBR

Origin:     Could be either human _or_ system error.
Solution:   Investigate the reason why you can't get a lock on the file,
            it is usually because of improper programming which causes
            race conditions on one or more files.
__bad_lock__


# CAN'T OPEN ON A DIRECTORY
'called open on a dir' => <<'__bad_open__',
$in->{_pak} can't call open() on this file because it is a directory
   $EBL$in->{filename}$EBR

Origin:     This is a human error.
Solution:   Use $in->{_pak}::load_file() to load the contents of a file
            Use $in->{_pak}::list_dir() to list the contents of a directory
__bad_open__


# CAN'T OPENDIR ON A FILE
'called opendir on a file' => <<'__bad_open__',
$in->{_pak} can't opendir() on this file because it is not a directory.
   $EBL$in->{filename}$EBR

Use $in->{_pak}::load_file() to load the contents of a file
Use $in->{_pak}::list_dir() to list the contents of a directory

Origin:     This is a human error.
Solution:   Use $in->{_pak}::load_file() to load the contents of a file
            Use $in->{_pak}::list_dir() to list the contents of a directory
__bad_open__


# CAN'T MKDIR ON A FILE
'called mkdir on a file' => <<'__bad_open__',
$in->{_pak} can't auto-create a directory for this path name because it
already exists as a file.
   $EBL$in->{filename}$EBR

Origin:     This is a human error.
Solution:   Resolve naming issue between the existent file and the directory
            you wish to create.
__bad_open__


# BAD CALL TO File::Util::readlimit
'bad readlimit' => <<'__maxdives__',
Bad call to $in->{_pak}::readlimit().  This method can only be called with
a numeric value (bytes).  Non-integer numbers will be converted to integer
format if specified (numbers like 5.2), but don't do that, it's inefficient.

This operation aborted.

Origin:     This is a human error.
Solution:   A human must fix the programming flaw.
__maxdives__


# EXCEEDED READLIMIT
'readlimit exceeded' => <<'__readlimit__',
$in->{_pak} can't load file: $EBL$in->{filename}$EBR
into memory because its size exceeds the maximum file size allowed
for a read.

The size of this file is $EBL$in->{size}$EBR bytes.

Currently the read limit is set at $EBL$READLIMIT$EBR bytes.

Origin:     This is a human error.
Solution:   Consider setting the limit to a higher number of bytes.
__readlimit__


# BAD CALL TO File::Util::max_dives
'bad maxdives' => <<'__maxdives__',
Bad call to $in->{_pak}::max_dives().  This method can only be called with
a numeric value (bytes).  Non-integer numbers will be converted to integer
format if specified (numbers like 5.2), but don't do that, it's inefficient.

This operation aborted.

Origin:     This is a human error.
Solution:   A human must fix the programming flaw.
__maxdives__


# EXCEEDED MAXDIVES
'maxdives exceeded' => <<'__maxdives__',
Recursion limit reached at $EBL${\ scalar(
   (exists $in->{maxdives} && defined $in->{maxdives}) ?
   $in->{maxdives} : $MAXDIVES) }$EBR dives.  Maximum number of subdirectory dives is set to the value returned by
$in->{_pak}::max_dives().  Try manually setting the value to a higher number
before calling list_dir() with option --follow or --recurse (synonymous).  Do
so by calling $in->{_pak}::max_dives() with the numeric argument corresponding
to the maximum number of subdirectory dives you want to allow when traversing
directories recursively.

This operation aborted.

Origin:     This is a human error.
Solution:   Consider setting the limit to a higher number.
__maxdives__


# BAD OPENDIR
'bad opendir' => <<'__bad_opendir__',
$in->{_pak} can't opendir on directory:
   $EBL$in->{dirname}$EBR

The system returned this error:
   $EBL$in->{exception}$EBR

Origin:     Could be either human _or_ system error.
Solution:   Cannot diagnose.  A Human must investigate the problem.
__bad_opendir__


# BAD MAKEDIR
'bad make_dir' => <<'__bad_make_dir__',
$in->{_pak} had a problem with the system while attempting to create the
directory you specified with a bitmask of $EBL$in->{bitmask}$EBR

directory: $EBL$in->{dirname}$EBR

The system returned this error:
   $EBL$in->{exception}$EBR

Origin:     Could be either human _or_ system error.
Solution:   Cannot diagnose.  A Human must investigate the problem.
__bad_make_dir__


# BAD CHARS
'bad chars' => <<'__bad_chars__',
$in->{_pak} can't use this string for $EBL$in->{purpose}$EBR.
   $EBL$in->{string}$EBR
It contains illegal characters.

Illegal characters are:
   \\   (backslash)
   /   (forward slash)
   :   (colon)
   |   (pipe)
   *   (asterisk)
   ?   (question mark)
   "   (double quote)
   <   (less than)
   >   (greater than)
   \\t  (tab)
   \\ck (vertical tabulator)
   \\r  (newline CR)
   \\n  (newline LF)

Origin:     This is a human error.
Solution:   A human must remove the illegal characters from this string.
__bad_chars__


# NOT A VALID FILEHANDLE
'not a filehandle' => <<'__bad_handle__',
$in->{_pak} can't unlock file with an invalid file handle reference:
   $EBL$in->{argtype}$EBR is not a valid filehandle

Origin:     This is most likely a human error, although it is remotely possible
            that this message is the result of an internal error in the
            $in->{_pak} module, but this is not likely if you called
            $in->{_pak}'s internal ::_release() method directly on your own.
Solution:   A human must fix the programming flaw.  Alternatively, in the
            second listed scenario, the package maintainer must investigate the
            problem.  Please send a usenet post with this error message in its
            entirety to Tommy Butler <tommy\@atrixnet.com>, or to usenet group:
            $EBL news://comp.lang.perl.modules $EBR
__bad_handle__


# BAD CALL TO METHOD FOO
'no input' => <<'__no_input__',
$in->{_pak} can't honor your call to $EBL$in->{_pak}::$in->{meth}()$EBR
because you didn't provide $EBL@{[$in->{missing}||'the required input']}$EBR

Origin:     This is a human error.
Solution:   A human must fix the programming flaw.
__no_input__


# PLAIN ERROR TYPE
'plain error' => <<'__plain_error__',
$in->{_pak} failed with the following message:
${\ scalar ($_[0] || ((exists $in->{error} && defined $in->{error}) ?
   $in->{error} : '[error unspecified]')) }
__plain_error__


# INVALID ERROR TYPE
'unknown error message' => <<'__foobar_input__',
$in->{_pak} failed with an invalid error-type designation.

Origin:     This is a bug!  Please inform Tommy Butler <tommy\@atrixnet.com>
Solution:   A human must fix the programming flaw.
__foobar_input__


# EMPTY ERROR TYPE
'empty error' => <<'__no_input__',
$in->{_pak} failed with an empty error-type designation.

Origin:     This is a human error.
Solution:   A human must fix the programming flaw.
__no_input__

   ); # end of error message table

   exists $error_msg_table{ $error_thrown }
   ? $error_msg_table{ $error_thrown }
   : $error_msg_table{'unknown error message'}
}

sub DESTROY {}
1;
