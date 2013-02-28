#!/bin/bash

dzil clean >/dev/null && dzil build >/dev/null;

. ~/perl5/perlbrew/etc/bashrc

for brew in 5.10.1  5.12.5  5.14.3  5.16.2  5.17.7  5.17.8  5.17.9  5.8.9; do

   perlbrew use perl-$brew;

   brewtmp="/tmp/brewtest/$( date +%s )/$brew/";

   mkdir -p $brewtmp;

   echo Trying in $brew ...;

   cpanm -L $brewtmp File-Util-*gz >/dev/null 2>&1 && echo "OK in $brew" || "FAILED IN $brew";

   rm -rf $brewtmp;

done
