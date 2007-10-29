#!/usr/athena/bin/perl
#
# Sync PTS lists listed in LIST:sipb-afs-sync between from the athena cell
#
# $Id$
#
# $Log $
#
use warnings;
use strict;
use Fatal qw(open);

use lib '/var/local/AFS/blib/lib';
use lib '/var/local/AFS/blib/arch/auto/AFS';

use AFS::PTS;
use AFS;

my $blanche = "/usr/athena/bin/blanche";

use constant AFS_NO_AUTH       => 0;
use constant AFS_OPTIONAL_AUTH => 1;
use constant AFS_REQUIRE_AUTH  => 2;

$ENV{KRBTKFILE} = "/tmp/tkt_moirasync";
$ENV{KRB5CCNAME} = "/tmp/krb5cc_moirasync";

system("/usr/athena/bin/kinit -k") == 0
  or die("Unable to kinit");
system("/bin/athena/aklog sipb.mit.edu") == 0
  or die("Unable to aklog");

my $athena = AFS::PTS->new(AFS_NO_AUTH, "athena.mit.edu")
  or die "Unable to authenticate to cell athena.mit.edu\n";
my $sipb = AFS::PTS->new(AFS_REQUIRE_AUTH, "sipb.mit.edu")
  or die "Unable to authenticate to cell sipb.mit.edu\n";

my $blacklist = "/var/local/sync/moira-sync.exclude";

my @errors;

sub read_list {
    my $list = shift;
    open(my $fh, "<", $list);
    my @list;
    my $ent;
    while(defined($ent = <$fh>)) {
        chomp($ent);
        next unless $ent =~ /^[[:alnum:]_-]+$/;
        push @list, $ent;
    }
    close($fh);
    return @list;
}

sub create_list {
    my $pts = shift;
    my $list = shift;
    
    if(!$pts->listentry($list)) {
        # warn "Creating AFS group $list in -c sipb\n";
        if(!$pts->creategroup($list, 'system:administrators')) {
            # warn "Unable to create list: $list -c sipb\n";
            push @errors, "Unable to create list $list: $AFS::CODE";
            return;
        }
    }
    return 1;
}

sub create_user {
    my $pts = shift;
    my $oldpts = shift;
    my $user = shift;
    my $id = shift;
    
    if(!$pts->listentry($user)) {
        # warn "Creating AFS user $user in -c sipb\n";
        my $id = $oldpts->id($user);
        if(!$id) {
            # warn "User $user doesn't exists in Athena cell?!";
            return;
        }
        if($pts->listentry($id)) {
            # warn "UID $id already exists in SIPB cell, not creating!";
            return;
        }
        
        if(!$pts->createuser($user, $id)) {
            # warn "Unable to create user: $user -c sipb\n";
	    push @errors, "Unable to create user $user: $AFS::CODE";
            return;
        }
    }
    return 1;
}

sub looks_like_user {
    my $thing = shift;
    return $thing =~ m{^[\w\d_-]+(?:[.][\w\d_-]+)?$};
}

my @sync;

open(my $pipe, "-|", "$blanche -noauth -l sipb-afs-sync");
while(<$pipe>) {
    chomp;
    s/^LIST://;
    push @sync, $_;
}
close($pipe);

my %blacklist = map {$_=>1} read_list($blacklist);

for my $list (@sync) {
    my $afslist;
    my $member;
    my %sipb;
    my %athena;
    
    if($blacklist{$list}) {
        # warn "Skipping blacklisted $list\n";
        next;
    }
    $afslist = "system:$list";
    if(!$athena->listentry($afslist)) {
        # warn "No such list: $list\n";
        next;
    }
    %athena = map {$_=>1} $athena->members($afslist);

    create_list($sipb, $afslist) or next;

    %sipb = map {$_=>1} $sipb->members("$afslist");

    for $member (keys %athena) {
        if(!looks_like_user($member)) {
            # warn "Skip non-user $member";
            next;
        }
        
        if(!$sipb{$member}) {
            # warn "Add $member to $list";
        } else {
            next;
        }

        if(!create_user($sipb, $athena, $member)) {
            # warn "Unable to create user $member in -c sipb";
            next;
        }

        if(!$sipb->adduser($member, $afslist)) {
            # warn "Unable to add user $member to $list";
	    push @errors, "Unable to add user $member to $list: $AFS::CODE";
        }
    }

    for $member (keys %sipb) {
        if(!looks_like_user($member)) {
            # warn "Skip non-user $member";
            next;
        }
        
        if(!$athena{$member}) {
            # warn "Remove $member from $list\n";
        } else {
            next;
        }
        
        if(!$sipb->removeuser($member, $afslist)) {
            # warn "Unable to remove user $member from $list";
	    push @errors, "Unable to remove $member from $list: $AFS::CODE";
        }
    }
}

my $mailto = 'sipb-afsreq@mit.edu';
my $mailrepl = $mailto;
my $host = `/bin/hostname`;
my $sendmail = '/usr/lib/sendmail';

if(@errors) {
    open(my $mail, "|-", "$sendmail -t -f$mailrepl");
    
    print $mail <<ENDMAIL;
From: root@$host
To: $mailto
Reply-To: $mailrepl
Subject: sipb<->athena pts sync errors

ENDMAIL
    foreach my $e (@errors) {
	print $mail "$e\n";
    }
    close($mail);
}


system("/usr/athena/bin/kdestroy >/dev/null 2>&1");
system("/bin/athena/unlog sipb.mit.edu");

