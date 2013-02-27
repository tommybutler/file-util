#!/usr/bin/perl
use strict;
use warnings;

BEGIN { sub say { print shift || 'Something is wrong'; print "\n" } } # << hack for old perl versions

use Encode 'is_utf8';

use lib 'lib';
use lib '../lib';

use File::Util;

my $ftl = File::Util->new();
my $tmpfile = 'utf8-encoded.txt';

say '-' x 70;
say 'Write temp file in UTF-8 mode';
$ftl->write_file( $tmpfile => qq(\x{c0}) => { binmode => 'utf8' } );

say 'Load file in raw mode';
my $content = $ftl->load_file( $tmpfile );

say 'Check if loaded content looks like UTF-8';
say Encode::is_utf8( $content )
   ? ' -> String is UTF-8 encoded'
   : ' -> String is NOT UTF-8 encoded';
say '...';

say 'Load file in UTF-8 mode';
$content = $ftl->load_file( $tmpfile => { binmode => 'utf8' } );

say 'Check if loaded content looks like UTF-8';
say is_utf8( $content )
   ? ' -> String is UTF-8 encoded'
   : ' -> String is NOT UTF-8 encoded';
say '...';

say 'Write file in raw mode';
$ftl->write_file( $tmpfile => qq(\x{c0}) );

say 'Load file in UTF-8 mode';
$content = $ftl->load_file( $tmpfile => { binmode => 'utf8' } );

say 'Check if loaded content looks like UTF-8';
say is_utf8( $content )
   ? ' -> String is UTF-8 encoded'
   : ' -> String is NOT UTF-8 encoded';
say '...';

say 'Load file in raw mode';
$content = $ftl->load_file( $tmpfile );

say 'Check if loaded content looks like UTF-8';
say is_utf8( $content )
   ? ' -> String is UTF-8 encoded'
   : ' -> String is NOT UTF-8 encoded';
say '...';

say 'Write file in UTF-8 mode with no unicode chars';
$ftl->write_file( $tmpfile => qq(foo!) => { binmode => 'utf8' } );

say 'Load file in UTF-8 mode';
$content = $ftl->load_file( $tmpfile => { binmode => 'utf8' } );

say 'Check if loaded content looks like UTF-8';
say is_utf8( $content )
   ? ' -> String is UTF-8 encoded'
   : ' -> String is NOT UTF-8 encoded';
say '...';

say 'Write file in raw mode with no unicode chars';
$ftl->write_file( $tmpfile => qq(foo!) );

say 'Load file in UTF-8 mode';
$content = $ftl->load_file( $tmpfile => { binmode => 'utf8' } );

say 'Check if loaded content looks like UTF-8';
say is_utf8( $content )
   ? ' -> String is UTF-8 encoded'
   : ' -> String is NOT UTF-8 encoded';
say '...';

say 'Removing temp file...';
unlink $tmpfile or die $!;
say 'Done.';

exit;

