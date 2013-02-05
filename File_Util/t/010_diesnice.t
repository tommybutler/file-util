
use strict;
use warnings;

use Test::More tests => 32;
use Test::NoWarnings ':early';

use lib './lib';
use File::Util qw( SL NL existent );

my $f = File::Util->new( fatals_as_errmsg => 1 );

# start testing failure sequence
# 1
like(
   $f->_throw(
      'no such file' =>
      {
         filename  => __FILE__,
         fatals_as_errmsg => 1
      }
   ), qr/inaccessible or does not exist/,
   'no such file'
);

# 2
like(
   $f->_throw(
      'bad flock rules' => {
         bad  => __FILE__,
         all => [ $f->flock_rules() ],
      }
   ),
   qr/Invalid file locking policy/,
   'bad flock rules'
);

# 3
like(
   $f->_throw(
      'cant fread' => {
         filename => __FILE__,
         dirname  => '.',
      }
   ),
   qr/Permissions conflict\..+?can't read the contents of this file:/,
   'cant fread'
);

# 4
like(
   $f->_throw( 'cant fread not found' => { filename => __FILE__ } ),
   qr/File not found\.  .+?can't read the contents of this file\:/,
   'cant fread no exists'
);

# 5
like(
   $f->_throw(
      'cant fcreate' => {
         filename => __FILE__,
         dirname  => '.',
      }
   ),
   qr/Permissions conflict\..+?can't create this file:/,
   'cant fcreate'
);

# 6
like( $f->_throw( 'cant write_file on a dir' => { filename => __FILE__ } ),
   qr/can't write to the specified file/,
   'cant write_file on a dir'
);

# 7
like(
   $f->_throw(
      'cant fwrite' => {
         filename => __FILE__,
         dirname  => '.',
      }
   ),
   qr/Permissions conflict\..+?can't write to this file:/,
   'cant fwrite'
);

# 8
like(
   $f->_throw(
      'bad openmode popen' => {
         filename => __FILE__,
         badmode  => 'illegal',
         meth     => 'anonymous',
      }
   ),
   qr/Illegal mode specified for file open\./,
   'bad openmode popen'
);

# 9
like(
   $f->_throw(
      'bad openmode sysopen' => {
         filename => __FILE__,
         badmode  => 'illegal',
         meth     => 'anonymous',
      }
   ),
   qr/Illegal mode specified for file sysopen/,
   'bad openmode sysopen'
);

# 10
like( $f->_throw( 'cant dread' => { dirname => '.' } ),
   qr/Permissions conflict\..+?can't list the contents of this/,
   'cant dread'
);

# 11
like(
   $f->_throw(
      'cant dcreate' => {
         dirname => '.',
         'parentd'  => '..',
      }
   ),
   qr/Permissions conflict\..+?can't create:/,
   'cant dcreate'
);

# 12
like(
   $f->_throw(
      'make_dir target exists' => {
         dirname  => '.',
         filetype => [ $f->file_type('.') ],
      }
   ),
   qr/make_dir target already exists\./,
   'make_dir target exists'
);

# 13
like(
   $f->_throw(
      'bad open' => {
         mode      => 'illegal mode',
         filename  => __FILE__,
         exception => 'dummy',
         cmd       => 'illegal cmd',
      }
   ),
   qr/can't open this file for.+?illegal mode/,
   'bad open'
);

# 14
like(
   $f->_throw(
      'bad close' => {
         mode      => 'illegal mode',
         filename  => __FILE__,
         exception => 'dummy',
      }
   ),
   qr/couldn't close this file after.+?illegal mode/,
   'bad close'
);

# 15
like(
   $f->_throw(
      'bad systrunc' => {
         filename  => __FILE__,
         exception => 'dummy',
      }
   ),
   qr/couldn't truncate\(\) on.+?after having/,
   'bad systrunc'
);

# 16
like(
   $f->_throw(
      'bad flock' => {
         filename  => __FILE__,
         exception => 'illegal',
      }
   ),
   qr/can't get a lock on the file/,
   'bad flock'
);

# 17
like( $f->_throw( 'called open on a dir' => { filename => __FILE__ } ),
   qr/can't call open\(\) on this file because it is a directory/,
   'called open on a dir'
);

# 18
like( $f->_throw( 'called opendir on a file' => { filename => __FILE__ } ),
   qr/can't opendir\(\) on this file because it is not a directory/,
   'called opendir on a file'
);

# 19
like( $f->_throw( 'called mkdir on a file' => { filename => __FILE__ } ),
   qr/can't auto-create a directory for this path name because/,
   'called mkdir on a file'
);

# 20
like( $f->_throw( 'bad readlimit' => {} ),
   qr/Bad call to .+?\:\:readlimit\(\)\.  This method can only be/,
   'bad readlimit'
);

# 21
like(
   $f->_throw(
      'readlimit exceeded' => {
         filename => __FILE__,
         size     => 'testtesttest',
      }
   ),
   qr/(?sm)can't load file.+?into memory because its size exceeds/,
   'readlimit exceeded'
);

# 22
like( $f->_throw( 'bad maxdives' => {} ),
   qr/Bad call to .+?\:\:max_dives\(\)\.  This method can only be/,
   'bad maxdives'
);

# 23
like( $f->_throw( 'maxdives exceeded' => {} ),
   qr/Recursion limit reached at .+?dives\.  Maximum number of/,
   'maxdives exceeded'
);

# 24
like(
   $f->_throw(
      'bad opendir' => {
         dirname   => '.',
         exception => 'illegal',
      }
   ),
   qr/can't opendir on directory\:/,
   'bad opendir'
);

# 25
like(
   $f->_throw(
      'bad make_dir' => {
         dirname   => '.',
         bitmask   => 0777,
         exception => 'illegal',
         meth      => 'anonymous',
      }
   ),
   qr/had a problem with the system while attempting to create/,
   'bad make_dir'
);

# 26
like(
   $f->_throw(
      'bad chars' => {
         string  => 'illegal characters',
         purpose => 'testing',
      }
   ),
   qr/(?sm)can't use this string.+?It contains illegal characters\./,
   'bad chars'
);

# 27
like( $f->_throw( 'not a filehandle' => { argtype => 'illegal' } ),
   qr/can't unlock file with an invalid file handle reference\:/,
   'not a filehandle'
);

# 28
like( $f->_throw( 'no input' => { meth => 'anonymous' } ),
   qr/(?sm)can't honor your call to.+?because you didn't provide/,
   'no input'
);

# 29
like( $f->_throw( 'plain error' => 'testtesttest' ),
   qr/failed with the following message\:/,
   'plain error'
);

# 30
like( $f->_throw( 'unknown error message', => {} ),
   qr/failed with an invalid error-type designation\./,
   'unknown error message'
);

# 31
like( $f->_throw( 'empty error', => {} ),
   qr/failed with an empty error-type designation\./,
   'empty error'
);

exit;
