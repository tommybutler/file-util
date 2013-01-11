
use strict;
use warnings;

use Test::More tests => 49;
use Test::NoWarnings;

use lib './lib';

use File::Util qw
   (
      SL   NL   escape_filename
      valid_filename   strip_path   needs_binmode
   );

my $f = File::Util->new();

# check asignability
my $NL = NL; my $SL = SL;

# newlines
ok( NL eq $NL, 'NL' );                                # test 1

# path seperator
ok( SL eq $SL, 'SL' );                                # test 2

# test file escaping with substitute escape char
# with additional char to escape as well.
ok                                                    # test 3
   (
      escape_filename(q[./foo/bar/baz.t/], '+','.') eq '++foo+bar+baz+t+',
      'escaped filename with custom escape'
   );

# test file escaping with defaults
ok                                                    # test 4
   (
      escape_filename(q[.\foo\bar\baz.t]) eq '._foo_bar_baz.t',
      'escaped filename with defaults'
   );

# test file escaping with option "--strip-path"
ok                                                    # test 5
   (
      escape_filename
         (
            q[.:foo:bar:baz.t],
            '--strip-path'
         ) eq 'baz.t'
   );

# path stripping in general
ok(strip_path(__FILE__) eq '004_portable.t');         # test 6
ok(strip_path('C:\foo') eq 'foo');                    # test 7
ok(strip_path('C:\foo\bar\baz.txt') eq 'baz.txt');    # test 8

# illegal filename character intolerance
ok(!valid_filename(qq[?foo]),qq[?foo]);          # question mark
ok(!valid_filename(qq[>foo]),qq[>foo]);          # greater than
ok(!valid_filename(qq[<foo]),qq[<foo]);          # less than
ok(!valid_filename(qq[<foo]),qq[<foo]);          # less than
ok(!valid_filename(qq[<foo]),qq[<foo]);          # less than
ok(!valid_filename(qq[<foo]),qq[<foo]);          # less than
ok(!valid_filename(qq[:foo]),qq[:foo]);          # colon
ok(!valid_filename(qq[*foo]),qq[*foo]);          # asterisk
ok(!valid_filename(qq[/foo]),qq[/foo]);          # forward slash
ok(!valid_filename(qq[\\foo]),qq[\\foo]);        # back slash
ok(!valid_filename(qq["foo]),qq["foo]);          # double quotation mark
ok(!valid_filename(qq[\tfoo]),qq[\\tfoo]);       # tab
ok(!valid_filename(qq[\013foo]),qq[\\013foo]);   # vertical tab
ok(!valid_filename(qq[\012foo]),qq[\\012foo]);   # newline
ok(!valid_filename(qq[\015foo]),qq[\\015foo]);   # form feed

# strange but legal filename character tolerance
ok(valid_filename(q['foo]),q['foo]);
ok(valid_filename(';foo'),';foo');
ok(valid_filename('$foo'),'$foo');
ok(valid_filename('%foo'),'%foo');
ok(valid_filename('`foo'),'`foo');
ok(valid_filename('!foo'),'!foo');
ok(valid_filename('@foo'),'@foo');
ok(valid_filename('#foo'),'#foo');
ok(valid_filename('^foo'),'^foo');
ok(valid_filename('&foo'),'&foo');
ok(valid_filename('-foo'),'-foo');
ok(valid_filename('_foo'),'_foo');
ok(valid_filename('+foo'),'+foo');
ok(valid_filename('=foo'),'=foo');
ok(valid_filename('(foo'),'(foo');
ok(valid_filename(')foo'),')foo');
ok(valid_filename('{foo'),'{foo');
ok(valid_filename('}foo'),'}foo');
ok(valid_filename('[foo'),'[foo');
ok(valid_filename(']foo'),']foo');
ok(valid_filename('~foo'),'~foo');
ok(valid_filename('.foo'),'.foo');
ok(valid_filename(q/;$%`!@#^&-_+=(){}[]~baz.foo'/),q/;$%`!@#^&-_+=(){}[]~baz.foo'/);
ok(valid_filename('C:\foo'),'C:\foo');

# directory listing tests...
# remove '.' and '..' directory entries
ok( sub{
   ( $f->_dropdots( qw/. .. foo/ ) )[0] eq 'foo'
      ? 'dots removed'
      : 'failed to remove dots'
}->() eq 'dots removed' );

exit;
