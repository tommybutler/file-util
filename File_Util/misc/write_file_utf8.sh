perl -Mlib=lib -Mlib=../lib -MFile::Util -e 'File::Util->new->write_file( "unicode.txt" => qq(\x{c0}) => { binmode => "utf8" } );'
echo new temp file "unicode.txt" details:
file -bi unicode.txt
rm -fv unicode.txt
