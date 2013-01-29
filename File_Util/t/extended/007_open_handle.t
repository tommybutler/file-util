
use strict;
use warnings;

use Test::More tests => 17;
use Test::NoWarnings;

use File::Temp qw( tempfile );

use lib './lib';
use File::Util qw( NL );

# one recognized instantiation setting
my $ftl = File::Util->new( );

my ( $tempfh, $tempfile ) = tempfile;

close $tempfh;

my $fh = $ftl->open_handle( $tempfile => 'write' );

is ref $fh, 'GLOB', 'got file handle for write';
is !!fileno( $fh ), 1, 'file handle open to a file descriptor';

print $fh 'dangerian' . NL . 'jspice' . NL . 'codizzle' . NL;

close $fh;

is fileno( $fh ), undef, 'closed file handle';

undef $fh;

$fh = $ftl->open_handle( $tempfile => 'read' );

is ref $fh, 'GLOB', 'got file handle for read';
is !!fileno( $fh ), 1, 'file handle open to a file descriptor';

my @lines = <$fh>;

chomp for @lines;

is_deeply
   \@lines,
   [ qw( dangerian jspice codizzle ) ],
   'read the lines just previously written';

close $fh;

is fileno( $fh ), undef, 'closed file handle';

undef $fh;
undef @lines;

$fh = $ftl->open_handle( $tempfile => 'append' );

is ref $fh, 'GLOB', 'got file handle for append';
is !!fileno( $fh ), 1, 'file handle open to a file descriptor';

print $fh 'redbeard' . NL . 'tbone' . NL;

close $fh;

is fileno( $fh ), undef, 'closed file handle';

undef $fh;

$fh = $ftl->open_handle( $tempfile ); # implicit mode => 'read'

is ref $fh, 'GLOB', 'got file handle for read';
is !!fileno( $fh ), 1, 'file handle open to a file descriptor';

@lines = <$fh>;

chomp for @lines;

is_deeply
   \@lines,
   [ qw( dangerian jspice codizzle redbeard tbone ) ],
   'read the lines just previously appended';

close $fh;

is fileno( $fh ), undef, 'closed file handle';

undef $fh;
undef @lines;

$fh = $ftl->open_handle( undef, { onfail => 'zero' } );

is $fh, 0, 'failed open with onfail => 0 handler returns 0';

$fh = $ftl->open_handle( undef, { onfail => 'undefined' } );

is $fh, undef, 'failed open with onfail => undefined handler returns undef';

exit;

