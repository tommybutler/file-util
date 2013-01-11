
use strict;
use warnings;
use Test::NoWarnings;
use Test::More tests => 13;

use lib './lib';
use File::Util;
use File::Util::Interface::Classic qw( _myargs _remove_opts _names_values );

# testing _myargs()
is_deeply( [ _myargs( qw/ a b c / ) ], [ qw/ a b c / ] );
is_deeply( [ _myargs( File::Util->new(), qw/ a b c / ) ], [ qw/ a b c / ] );
is( _myargs( 'a' ), 'a' );
is( scalar _myargs( qw/ a b c / ), 'a' );

# testing _remove_opts()
is( _remove_opts( 'a' ), undef );
is( _remove_opts( qw/ a b c / ), undef );
is_deeply(
   _remove_opts( [ qw/ --name=Larry --lang=Perl --recurse /, '--empty=' ] ),
   {
      '--name'    => 'Larry',
      'name'      => 'Larry',
      '--lang'    => 'Perl',
      'lang'      => 'Perl',
      '--recurse' => '--recurse',
      'recurse'   => 'recurse',
      '--empty'   => '',
      'empty'     => '',
   }
);
is_deeply(
   _remove_opts(
      [
         File::Util->new(),
         qw/ --name=Larry --lang=Perl --recurse /, '--empty='
      ]
   ),
   {
      '--name'    => 'Larry',
      'name'      => 'Larry',
      '--lang'    => 'Perl',
      'lang'      => 'Perl',
      '--recurse' => '--recurse',
      'recurse'   => 'recurse',
      '--empty'   => '',
      'empty'     => '',
   }
);

# testing _names_values
is_deeply(
   _names_values( qw/ a a b b c c d d e e / ),
   { a => a => b => b => c => c => d => d => e => e => }
);
is_deeply(
   _names_values( File::Util->new(), qw/ a a b b c c d d e e / ),
   { a => a => b => b => c => c => d => d => e => e => }
);
is_deeply(
   _names_values( a => 'a',  'b' ),
   { a => a => b => undef }
);
is_deeply(
   _names_values( a => 'a',  b => 'b', ( undef, 'u' ), c => 'c' ), # foolishness
   { a => a => b => b => c => c => } # ...should go ignored (at least here)
);

exit;
