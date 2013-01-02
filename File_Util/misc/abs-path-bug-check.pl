#!/usr/bin/perl

use lib '.';
use File::Util qw( NL );

print qq{Rollin' with File::Util v.$File::Util::VERSION\n\n};

my $f = File::Util->new();

# test for absolute paths regression bug from the developer's standpoint
print join NL, $f->list_dir('/var/tmp', '--recurse', '--sl-after-dirs');

print qq{\n\nI FINISHED!!  I FINISHED!!\n};

exit;

