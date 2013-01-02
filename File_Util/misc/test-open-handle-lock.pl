#!/usr/bin/perl

use strict;
use warnings;

BEGIN { $ENV{FTLDEBUG}++ }

use lib '/home/superman/projects/personal/perl/CPAN/File_Util/File_Util/lib';

use File::Util qw( NL );

print "Rolling with File::Util v$File::Util::VERSION\n";

my $f   = File::Util->new( '--fatals-as-status' );
my $fn  = "/tmp/foo$$";
my $msg = "flock()ed with love, from Hong Kong, on ${\ scalar localtime }" . NL;
my $fh  = $f->open_handle( file => $fn, mode => 'write' );

print qq{Opened tempfile $fn on fileno } . fileno $fh, NL;

print $fh $msg;

print '...And print()ed a silly string to it.' . NL;

# this MUST fail!
print 'Going to try and open the tempfile again, but it should be locked' . NL;

my $fh_fail = $f->open_handle( file => $fn, mode => 'write' )
   && die 'THAT SHOULD HAVE FAILED!';

print q{Fileno for the attempted re-open filehandle is } .
   (
      defined fileno $fh_fail
         ? fileno $fh_fail
         : 'undef, just like it should be.'
   ) . NL;

close $fh;

print 'Closed tempfile' . NL;
print 'Reading tempfile contents:' . NL;
print " ...$fn contents: ", $f->load_file( $fn );

unlink $fn or warn "Couldn't unlink $fn => $!";

exit;
