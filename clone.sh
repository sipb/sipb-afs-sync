#!/bin/sh
#
# Reclone all backup volumes in the entire cell except those that are 
# replicated.  We'll get those later.
# $Id$
#
# $Log$
# Revision 1.3  2011/12/23 19:42:24  mitchb
# Uncommitted change from forever ago to use -quiet with 'vos listvldb'
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

volumes=`$vos listvldb -c $cell -quiet -noauth | /usr/athena/bin/perl -e 'while(<>) { chop; unless (m/^\s/ || m/^\s*$/ || m/\.nb\s*$/ || m/^disk\./ || m/^Total entries:/ || m/^n\./ ) { print $_, "\n"; } }'`

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
