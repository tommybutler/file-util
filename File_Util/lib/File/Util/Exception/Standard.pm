use strict;
use warnings;

use lib 'lib';

package File::Util::Exception::Standard;

use File::Util::Definitions qw( :all );
use File::Util::Exception qw( :all );

use vars qw(
   @ISA    $AUTHORITY
   @EXPORT_OK  %EXPORT_TAGS
);

use Exporter;

$AUTHORITY   = 'cpan:TOMMY';
@ISA         = qw( Exporter File::Util::Exception );
@EXPORT_OK   = ( '_errors', @File::Util::Exception::EXPORT_OK );
%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );


#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#
# STANDARD (VERBOSE) ERROR MESSAGES
#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#%#
sub _errors {
   my ( $this, $error_thrown ) = @_;

   $error_thrown ||= $this;

   # begin long table of helpful diag error messages
   my %error_msg_table = (
# NO SUCH FILE
'no such file' => <<'__bad_open__',
File inaccessable or does not exist: $EBL$opts->{filename}$EBR
__bad_open__


# BAD FLOCK RULE POLICY
'bad flock rules' => <<'__bad_lockrules__',
Invalid file locking policy can not be implemented.
__bad_lockrules__


# CAN'T READ FILE - PERMISSIONS
'cant fread' => <<'__cant_read__',
Permissions conflict.  Can't read: $EBL$opts->{filename}$EBR
__cant_read__


# CAN'T READ FILE - NOT EXISTENT
'cant fread not found' => <<'__cant_read__',
File not found: $EBL$opts->{filename}$EBR
__cant_read__


# CAN'T CREATE FILE - PERMISSIONS
'cant fcreate' => <<'__cant_write__',
Permissions conflict.  Can't create: $EBL$opts->{filename}$EBR
__cant_write__


# CAN'T WRITE TO FILE - EXISTS AS DIRECTORY
'cant write_file on a dir' => <<'__bad_writefile__',
File already exists as directory:  $EBL$opts->{filename}$EBR
__bad_writefile__


# CAN'T TOUCH A FILE - EXISTS AS DIRECTORY
'cant touch on a dir' => <<'__bad_touchfile__',
File already exists as directory:  $EBL$opts->{filename}$EBR
__bad_touchfile__


# CAN'T WRITE TO FILE
'cant fwrite' => <<'__cant_write__',
Permissions conflict.  Can't write to: $EBL$opts->{filename}$EBR
__cant_write__


# BAD OPEN MODE - PERL
'bad openmode popen' => <<'__bad_openmode__',
Illegal mode specified for file open: $EBL$opts->{badmode}$EBR
__bad_openmode__


# BAD OPEN MODE - SYSOPEN
'bad openmode sysopen' => <<'__bad_openmode__',
Illegal mode specified for sysopen: $EBL$opts->{badmode}$EBR
__bad_openmode__


# CAN'T LIST DIRECTORY
'cant dread' => <<'__cant_read__',
Permissions conflict.  Can't list directory: $EBL$opts->{dirname}$EBR
__cant_read__


# CAN'T CREATE DIRECTORY - PERMISSIONS
'cant dcreate' => <<'__cant_dcreate__',
Permissions conflict.  Can't create directory: $EBL$opts->{dirname}$EBR
__cant_dcreate__


# CAN'T CREATE DIRECTORY - TARGET EXISTS
'make_dir target exists' => <<'__cant_dcreate__',
make_dir target already exists: $EBL$opts->{dirname}$EBR
__cant_dcreate__


# CAN'T OPEN
'bad open' => <<'__bad_open__',
Can't open: $EBL$opts->{filename}$EBR for: $EBL$opts->{mode}$EBR
OS error if any: $EBL$!$EBR
__bad_open__


# BAD CLOSE
'bad close' => <<'__bad_close__',
Couldn't close: $EBL$opts->{filename}$EBR
OS error if any: $EBL$!$EBR
__bad_close__


# CAN'T TRUNCATE
'bad systrunc' => <<'__bad_systrunc__',
Couldn't truncate() on $EBL$opts->{filename}$EBR
OS error if any: $EBL$!$EBR
__bad_systrunc__


# CAN'T GET FLOCK AFTER BLOCKING
'bad flock' => <<'__bad_lock__',
Can't get a lock on the file: $EBL$opts->{filename}$EBR
OS error if any: $EBL$!$EBR
__bad_lock__


# CAN'T OPEN ON A DIRECTORY
'called open on a dir' => <<'__bad_open__',
Can't call open() on a directory: $EBL$opts->{filename}$EBR
__bad_open__


# CAN'T OPENDIR ON A FILE
'called opendir on a file' => <<'__bad_open__',
Can't opendir() on non-directory: $EBL$opts->{filename}$EBR
__bad_open__


# CAN'T MKDIR ON A FILE
'called mkdir on a file' => <<'__bad_open__',
Can't make directory; already exists as a file.  $EBL$opts->{filename}$EBR
__bad_open__


# BAD CALL TO File::Util::readlimit
'bad readlimit' => <<'__maxdives__',
Bad input provided to readlimit().
__maxdives__


# EXCEEDED READLIMIT
'readlimit exceeded' => <<'__readlimit__',
Stopped reading: $EBL$opts->{filename}$EBR  Readlimit exceeded: $READLIMIT bytes
__readlimit__


# BAD CALL TO File::Util::max_dives
'bad maxdives' => <<'__maxdives__',
Bad input provided to max_dives()
__maxdives__


# EXCEEDED MAXDIVES
'maxdives exceeded' => <<'__maxdives__',
Recursion limit exceeded at $EBL${\ scalar(
   (exists $opts->{maxdives} && defined $opts->{maxdives}) ?
   $opts->{maxdives} : $MAXDIVES)
}$EBR dives.
__maxdives__


# BAD OPENDIR
'bad opendir' => <<'__bad_opendir__',
Can't opendir on directory: $EBL$opts->{dirname}$EBR
OS error if any: $EBL$!$EBR
__bad_opendir__


# BAD MAKEDIR
'bad make_dir' => <<'__bad_make_dir__',
Can't create directory: $EBL$opts->{dirname}$EBR
OS error if any: $EBL$!$EBR
__bad_make_dir__


# BAD CHARS
'bad chars' => <<'__bad_chars__',
String contains illegal characters: $EBL$opts->{string}$EBR
__bad_chars__


# NOT A VALID FILEHANDLE
'not a filehandle' => <<'__bad_handle__',
Can't unlock file with an invalid file handle reference
__bad_handle__


# BAD CALL TO METHOD FOO
'no input' => <<'__no_input__',
$opts->{_pak} can't honor your call to $EBL$opts->{_pak}::$opts->{meth}()$EBR
because you didn't provide $EBL@{[$opts->{missing}||'the required input']}$EBR
__no_input__


# PLAIN ERROR TYPE
'plain error' => <<'__plain_error__',
${\ scalar ($_[0] || ((exists $opts->{error} && defined $opts->{error}) ?
   $opts->{error} : '[error unspecified]')) }
__plain_error__


# INVALID ERROR TYPE
'unknown error message' => <<'__foobar_input__',
Failed with an invalid error-type designation.
This is a bug!  Please File A Bug Report!
__foobar_input__


# EMPTY ERROR TYPE
'empty error' => <<'__no_input__',
Failed with an empty error-type designation.
__no_input__

   ); # end of error message table

   exists $error_msg_table{ $error_thrown }
   ? $error_msg_table{ $error_thrown }
   : $error_msg_table{'unknown error message'}
}

1;


__END__

=pod

=head1 NAME

File::Util::Exception::Standard

=head1 DESCRIPTION

Provides error messages when things go wrong.  Use the
C<L<File::Util::Exception::Diagnostic>> module if you want more helpful
error messages.

Standard use (without diagnostics):

   use File::Util;

Debug/troubleshooting use (with diagnostics):

   use File::Util qw( :diag );

Users, please don't use this module by itself (directly).  It is for
internal use only.

=cut

