#!/bin/sh
#
# second generation of the script that autoreleases all replicated volumes
# in the sipb cell
#
# Garry Zacheiss <zacheiss@mit.edu>, 2 Aug 1999
#
# $Id$
#
# $Log$
# Revision 1.1  2000/01/20 19:07:09  zacheiss
# script which automatically releases replicated volumes in the sipb cell nightly.
#
# Revision 1.1  1999/08/10 07:00:06  root
# Initial revision
#
#

vos=/usr/afs/bin/vos
cell=sipb.mit.edu
errs=/tmp/release.errs.$$
header=/tmp/release.hdr.$$
mailto=sipb-afsreq@mit.edu
mailrepl=sipb-afsreq@mit.edu
host=`/bin/hostname`
excludefile=/var/local/sync/release.excludes

# Build up a egrep regular expression from the excludes file

exclude="^(`xargs < $excludefile | sed 's/ /|/g'`)$"

volumes=`$vos listvldb -c $cell -noauth | /usr/athena/bin/perl -e 'while(<>) { if (/^(\S+)/) { $vol = $1; } if (/ROnly/) { print $vol,"\n"; } }' | egrep -v $exclude`

for vol in $volumes; do 
    $vos release $vol -c $cell -localauth >/dev/null 2>>$errs
    sleep 5
done

if [ -s $errs ]; then
    cat > $header <<EOF
From: root@${host}
To: $mailto
Reply-To: $mailrepl
Subject: $cell cell volume release errors

EOF

    (cat $header; cat $errs) | /usr/lib/sendmail -t -f${mailrepl}
else 
    rm -f $errs
fi
