#!/bin/sh
#
# Reclone all backup volumes in the entire cell except those that are 
# replicated.  We'll get those later.
# $Id$
#
# $Log$
# Revision 1.1  2000/01/20 19:07:09  zacheiss
# automated cloning, run nightly from reynelda.
#
# Revision 1.1  1999/12/09 14:16:18  root
# Initial revision
#
#

vos=/usr/afs/bin/vos
cell=sipb.mit.edu
errs=/tmp/clone.errs.$$
header=/tmp/clone.hdr.$$
mailto=sipb-afsreq@mit.edu
mailrepl=sipb-afsreq@mit.edu
host=`/bin/hostname`
KRBTKFILE=/tmp/tkt_cloning; export KRBTKFILE
KRB5CCNAME=/tmp/krb5cc_cloning; export KRB5CCNAME

/usr/athena/bin/kinit -k
/bin/athena/aklog $cell

/usr/athena/bin/zwrite -q -c sipb-auto -i backups -s reynelda -O auto -m "Beginning automated cloning."

touch /afs/.$cell/service/DOING_CLONING

volumes=`$vos listvldb -c $cell -noauth | /usr/athena/bin/perl -e 'while(<>) { if (/^(\S+)/) { $vol = $1; } if (/Backup/) { print $vol,"\n"; } }'`

for vol in $volumes; do
    $vos backup $vol -c $cell -localauth >/dev/null 2>>$errs
    sleep 1
done

if [ -s $errs ]; then
    cat > $header <<EOF
From: root@${host}
To: $mailto
Reply-To: $mailrepl
Subject: $cell cell nightly cloning errors

EOF

    (cat $header; cat $errs) | /usr/lib/sendmail -t -f${mailrepl}
else
    rm -f $errs
fi

rm -f /afs/.$cell/service/DOING_CLONING

/usr/athena/bin/zwrite -q -c sipb-auto -i backups -s reynelda -O auto -m "Done with automated cloning."

/usr/athena/bin/kdestroy >/dev/null 2>&1
/bin/athena/unlog $cell

exit 0
