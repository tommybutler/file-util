
use strict;
use Test;

# use a BEGIN block so we print our plan before MyModule is loaded
BEGIN { plan tests => 31, todo => [] }
BEGIN { $| = 1 }

# load your module...
use lib './';
use File::Util qw( SL NL existent );

my($f) = File::Util->new('--fatals-as-errmsg');

# start testing failure sequence
# 1
ok($f->_throw('no such file' => { 'filename'  => __FILE__ }, '--fatals-as-errmsg' ),
   q{/inaccessible or does not exist/},
   q{Bad failure return code for error: "no such file"}
);

# 2
ok(
   $f->_throw(
      'bad flock rules' => {
         'bad'  => __FILE__,
         'all' => [ $f->flock_rules() ],
      }
   ),
   q{/Invalid file locking policy/},
   q{Bad failure return code for error: "bad flock rules"}
);

# 3
ok(
   $f->_throw(
      'cant fread' => {
         'filename' => __FILE__,
         'dirname'  => '.',
      }
   ),
   q{/Permissions conflict\..+?can't read the contents of this file:/},
   q{Bad failure return code for error: "cant fread"}
);

# 4
ok($f->_throw('cant fread not found' => { 'filename' => __FILE__, }),
   q{/File not found\.  .+?can't read the contents of this file\:/},
   q{Bad failure return code for error: "cant fread no exists"}
);

# 5
ok(
   $f->_throw(
      'cant fcreate' => {
         'filename' => __FILE__,
         'dirname'  => '.',
      }
   ),
   q{/Permissions conflict\..+?can't create this file:/},
   q{Bad failure return code for error: "cant fcreate"}
);

# 6
ok($f->_throw('cant write_file on a dir' => { 'filename' => __FILE__, }),
   q{/can't write to the specified file/},
   q{Bad failure return code for error: "cant write_file on a dir"}
);

# 7
ok(
   $f->_throw(
      'cant fwrite' => {
         'filename' => __FILE__,
         'dirname'  => '.',
      }
   ),
   q{/Permissions conflict\..+?can't write to this file:/},
   q{Bad failure return code for error: "cant fwrite"}
);

# 8
ok(
   $f->_throw(
      'bad openmode popen' => {
         'filename' => __FILE__,
         'badmode'  => 'illegal',
         'meth'     => 'anonymous',
      }
   ),
   q{/Illegal mode specified for file open\./},
   q{Bad failure return code for error: "bad openmode popen"}
);

# 9
ok(
   $f->_throw(
      'bad openmode sysopen' => {
         'filename' => __FILE__,
         'badmode'  => 'illegal',
         'meth'     => 'anonymous',
      }
   ),
   q{/Illegal mode specified for file sysopen/},
   q{Bad failure return code for error: "bad openmode sysopen"}
);

# 10
ok($f->_throw('cant dread' => { 'dirname' => '.' } ),
   q{/Permissions conflict\..+?can't list the contents of this/},
   q{Bad failure return code for error: "cant dread"}
);

# 11
ok(
   $f->_throw(
      'cant dcreate' => {
         'dirname' => '.',
         'parentd'  => '..',
      }
   ),
   q{/Permissions conflict\..+?can't create:/},
   q{Bad failure return code for error: "cant dcreate"}
);

# 12
ok(
   $f->_throw(
      'make_dir target exists' => {
         'dirname'  => '.',
         'filetype' => [ $f->file_type('.') ],
      }
   ),
   q{/make_dir target already exists\./},
   q{Bad failure return code for error: "make_dir target exists"}
);

# 13
ok(
   $f->_throw(
      'bad open' => {
         'mode'      => 'illegal mode',
         'filename'  => __FILE__,
         'exception' => 'dummy',
         'cmd'       => 'illegal cmd',
      }
   ),
   q{/can't open this file for.+?illegal mode/},
   q{Bad failure return code for error: "bad open"}
);

# 14
ok(
   $f->_throw(
      'bad close' => {
         'mode'      => 'illegal mode',
         'filename'  => __FILE__,
         'exception' => 'dummy',
      }
   ),
   q{/couldn't close this file after.+?illegal mode/},
   q{Bad failure return code for error: "bad close"}
);

# 15
ok(
   $f->_throw(
      'bad systrunc' => {
         'filename'  => __FILE__,
         'exception' => 'dummy',
      }
   ),
   q{/couldn't truncate\(\) on.+?after having/},
   q{Bad failure return code for error: "bad systrunc"}
);

# 16
ok(
   $f->_throw(
      'bad flock' => {
         'filename'  => __FILE__,
         'exception' => 'illegal',
      }
   ),
   q{/can't get a lock on the file/},
   q{Bad failure return code for error: "bad flock"}
);

# 17
ok($f->_throw('called open on a dir' => { 'filename' => __FILE__ }),
   q{/can't call open\(\) on this file because it is a directory/},
   q{Bad failure return code for error: "called open on a dir"}
);

# 18
ok($f->_throw('called opendir on a file' => { 'filename' => __FILE__ }),
   q{/can't opendir\(\) on this file because it is not a directory/},
   q{Bad failure return code for error: "called opendir on a file"}
);

# 19
ok($f->_throw('called mkdir on a file' => { 'filename' => __FILE__ }),
   q{/can't auto-create a directory for this path name because/},
   q{Bad failure return code for error: "called mkdir on a file"}
);

# 20
ok($f->_throw('bad readlimit' => {}),
   q{/Bad call to .+?\:\:readlimit\(\)\.  This method can only be/},
   q{Bad failure return code for error: "bad readlimit"}
);

# 21
ok(
   $f->_throw(
      'readlimit exceeded' => {
         'filename' => __FILE__,
         'size'     => 'testtesttest',
      }
   ),
   q{/(?sm)can't load file.+?into memory because its size exceeds/},
   q{Bad failure return code for error: "readlimit exceeded"}
);

# 22
ok($f->_throw('bad maxdives' => {}),
   q{/Bad call to .+?\:\:max_dives\(\)\.  This method can only be/},
   q{Bad failure return code for error: "bad maxdives"}
);

# 23
ok($f->_throw('maxdives exceeded' => {}),
   q{/Recursion limit reached at .+?dives\.  Maximum number of/},
   q{Bad failure return code for error: "maxdives exceeded"}
);

# 24
ok(
   $f->_throw(
      'bad opendir' => {
         'dirname'   => '.',
         'exception' => 'illegal',
      }
   ),
   q{/can't opendir on directory\:/},
   q{Bad failure return code for error: "bad opendir"}
);

# 25
ok(
   $f->_throw(
      'bad make_dir' => {
         'dirname'   => '.',
         'bitmask'   => 0777,
         'exception' => 'illegal',
         'meth'      => 'anonymous',
      }
   ),
   q{/had a problem with the system while attempting to create/},
   q{Bad failure return code for error: "bad make_dir"}
);

# 26
ok(
   $f->_throw(
      'bad chars' => {
         'string'  => 'illegal characters',
         'purpose' => 'testing',
      }
   ),
   q{/(?sm)can't use this string.+?It contains illegal characters\./},
   q{Bad failure return code for error: "bad chars"}
);

# 27
ok($f->_throw('not a filehandle' => { 'argtype'  => 'illegal', }),
   q{/can't unlock file with an invalid file handle reference\:/},
   q{Bad failure return code for error: "not a filehandle"}
);

# 28
ok($f->_throw('no input' => { 'meth' => 'anonymous' }),
   q{/(?sm)can't honor your call to.+?because you didn't provide/},
   q{Bad failure return code for error: "no input"}
);

# 29
ok($f->_throw('plain error' => 'testtesttest'),
   q{/failed with the following message\:/},
   q{Bad failure return code for error: "plain error"}
);

# 30
ok($f->_throw('unknown error message', => {}),
   q{/failed with an invalid error-type designation\./},
   q{Bad failure return code for error: "unknown error message"}
);

# 31
ok($f->_throw('empty error', => {}),
   q{/failed with an empty error-type designation\./},
   q{Bad failure return code for error: "empty error"}
);

exit;

