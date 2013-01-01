#!/usr/bin/perl

BEGIN {
   chdir '/home/tommy/projects';
};

use lib '.';
use File::Util;
use File::Footil;

print qq{Rollin' with File::Util v.$File::Util::VERSION\n\n};

#my $f = File::Util->new();
my $f = File::Util->new('--fatals-as-status');

print join "\n", $f->list_dir('/var/tmp', '--recurse', '--sl-after-dirs');

print qq{\n\nI FINISHED!!  I FINISHED!!\n};

exit;

