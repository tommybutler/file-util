
use lib '../lib';
use File::Util;
use Exception::Handler;

my $ftl = File::Util->new();

my $file_handle = $ftl->open_handle(
   '/this/might/not/work' => {
      diag   => 1,
      onfail => sub {
         my ( $err, $trace ) = @_;

         warn "Couldn't open first choice, trying a backup plan... at:\n" .
            $err . $trace;

         return $ftl->open_handle( '/tmp/file.txt' );
      },
   }
);

print while <$file_handle>;
