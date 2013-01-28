
# this was the sandbox used to develop t/extended/006_onfail.t
#
use strict;
use warnings;

use vars qw( $stderr_str $callback_err $sig_warn );

$sig_warn = $SIG{__WARN__};

$SIG{__WARN__} = sub { $stderr_str .= join '', @_; return };

use lib 'lib';
use File::Util;

my $ftl = File::Util->new();

$ftl->write_file( '/root/foobar' => 'hi', => { onfail => 'warn' } );

$SIG{__WARN__} = $sig_warn;

$ftl->write_file( '/root/foobar' => 'hi', => { onfail => \&fail_callback  } );

my $zero      = $ftl->write_file( '/root/foobar' => 'hi', => { onfail => 'zero' } );
my $undefined = $ftl->write_file( '/root/foobar' => 'hi', => { onfail => 'undefined' } );
my $err_msg   = $ftl->write_file( '/root/foobar' => 'hi', => { onfail => 'message' } );
my $die_msg   = '';

{
   local $@;

   eval { $ftl->write_file( '/root/foobar' => 'hi', => { onfail => 'die' } ); };

   $die_msg = $@;
}

clean_err( \$err_msg );
clean_err( \$die_msg );
clean_err( \$stderr_str );
clean_err( \$callback_err );

print $err_msg eq $stderr_str ? 'OK error message same as warning' : 'error message differed from warning';
print "\n";

print $die_msg eq $stderr_str ? 'OK die message same as warning' : 'die message differed from warning';
print "\n";

print $callback_err eq $stderr_str ? 'OK callback error same as warning' : 'callback error differed from warning';
print "\n";

print $zero == 0 ? 'OK Returned 0, as expected' : 'Should have returned 0, but did not';
print "\n";

print !defined $undefined ? 'OK Returned undef, as expected' : 'Should have returned undef, but did not';
print "\n";

=begin comment

print "\n";
print '-' x 80, "\n";
print $err_msg;
print '-' x 80, "\n";
print $callback_err;

=cut

exit;

sub fail_callback {
   my ( $err, $stack ) = @_;
   $callback_err = "\n" . $err . $stack;
};

sub clean_err {
   my $err = shift @_;
   $$err =~ s/^.*called at line.*$//mg;
   $$err =~ s/\n\n2\. .*//sm; # delete everything after stack frame 1
};

