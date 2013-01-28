
use strict;
use warnings;
use Test::More;
use Test::NoWarnings;

# useful snippet for potential version-dependent tests in the future

{
   local $@ = undef;

   eval { require 5.8.0; };

   die qq(Only have version $], but need 5.8.0 or greater) if $@;

   # or "plan skip all" if lower version
}
