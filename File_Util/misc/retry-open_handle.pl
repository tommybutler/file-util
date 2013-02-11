
use lib 'lib';
use lib '../lib';

use File::Util qw( NL );
use Exception::Handler;

my $ftl = File::Util->new();
my $for_sure_file = '/tmp/file.txt';

my $file_handle = $ftl->open_handle(
   '/this/might/not/work' => {
      mode   => 'append',
      onfail => sub {
         my ( $err, $trace ) = @_;

         #warn "Couldn't open first choice, trying a backup plan...";

         #warn $err . $trace;

         return $ftl->open_handle( $for_sure_file => { mode => 'append' } );
      },
   }
);

print $file_handle scalar localtime;
print $file_handle NL;

close $file_handle;

print $ftl->load_file( $for_sure_file );


