
use strict;
use warnings;

exit; # it should just compile, not run

# SYNOPSIS snapshot: Sun Jan 27 19:04:34 CST 2013

   use File::Util;

   # create a new File::Util object
   my $f = File::Util->new();

   # load content into a variable, be it text, or binary, either works
   my $content = $f->load_file( 'Meeting Notes.txt' );

   # wrangle text
   $content =~ s/this/that/g;

   # re-write the file with your changes
   $f->write_file(
      file => 'Meeting Notes.txt',
      content => $content,
   );

   # try binary this time
   my $binary_content = $f->load_file( 'cat-movie.avi' );

   # get some image data from somewhere...
   my $picture_data = get_image_upload();

   # ...and write a binary image file, using some other options as well
   $f->write_file(
      file => 'llama.jpg',
      content => $picture_data,
      { binmode => 1, bitmask => oct 644 }
   );

   # load a file into an array, line by line
   my @lines = $f->load_file( 'file.txt' => { as_lines => 1 } );

   # get an open file handle for reading
   my $fh = $f->open_handle( file => 'Ian likes cats.txt', mode => 'read' );

   while ( my $line = <$fh> ) { # read the file, line by line

      # ... do stuff
   }

   close $fh or die $!; # don't forget to close ;-)

   # get an open file handle for writing
   $fh = $f->open_handle(
      file => 'John prefers dachshunds.txt',
      mode => 'write'
   );

   print $fh 'Shout out to Bob!';

   close $fh or die $!; # _never_ forget to close ;-)

   # get a listing of files, recursively, skipping directories
   my @files = $f->list_dir( '/var/tmp' => { files_only => 1, recurse => 1 } );

   # get a listing of text files, recursively
   my @textfiles = $f->list_dir(
      '/var/tmp' => {
         files_match => qr/\.txt$/,
         files_only  => 1,
         recurse     => 1,
      }
   );

   # walk a directory, using an anonymous function or function ref as a
   # callback (higher order Perl)
   $f->list_dir( '/home/larry' => {
      recurse  => 1,
      callback => sub {
         my ( $selfdir, $subdirs, $files ) = @_;

         print "In $selfdir there are...\n";

         print scalar @$subdirs . " subdirectories, and ";
         print scalar @$files   . " files\n";

         for my $file ( @$files ) {

            # ... do something with $file
         }
      },
   } );

   # get an entire directory tree as a hierarchal datastructure reference
   my $tree = $f->list_dir( '/my/podcasts' => { as_tree => 1 } );

   # see if you have permission to write to a file, then append to it
   # using an auto-flock'd filehandle (for operating systems that support flock)
   # ...you can also use the write_file() method in append mode as well...

   if ( $f->can_write( 'captains.log' ) ) {

      my $fh = $f->open_handle(
         file => 'captains.log',
         mode => 'append'
      );

      print $fh "Captain's log, stardate 41153.7.  Our destination is...";

      close $fh or die $!;
   }
   else { # ...or warn the crew

      warn "Trouble on the bridge, the Captain can't access his log!";
   }

   # get the number of lines in a file
   my $log_line_count = $f->line_count( '/var/log/messages' );

   # the next several examples show how to get different information about files

   print "My file has a bitmask of " . $f->bitmask( 'my.file' );

   print "My file is a " . join(', ', $f->file_type( 'my.file' )) . " file.";

   warn 'This file is binary!' if $f->isbin( 'my.file' );

   print 'My file was last modified on ' .
      scalar localtime $f->last_modified( 'my.file' );
