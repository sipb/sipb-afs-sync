#!/usr/bin/env perl
use warnings;
use strict;
use Fatal qw(open);

use AFS::PTS;

use constant AFS_NO_AUTH       => 0;
use constant AFS_OPTIONAL_AUTH => 1;
use constant AFS_REQUIRE_AUTH  => 2;

my $athena = AFS::PTS->new(AFS_NO_AUTH, "athena.mit.edu")
  or die "Unable to authenticate to cell athena.mit.edu\n";
my $sipb = AFS::PTS->new(AFS_REQUIRE_AUTH, "sipb.mit.edu")
  or die "Unable to authenticate to cell sipb.mit.edu\n";

my $synclist = "/home/nelhage/mit/sipb/afs-moira/sync-list";
my $blacklist = "/home/nelhage/mit/sipb/afs-moira/blacklist";

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
        warn "Creating AFS group $list in -c sipb\n";
        if(!$pts->creategroup($list, 'system:administrators')) {
            warn "Unable to create list: $list -c sipb\n";
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
        warn "Creating AFS user $user in -c sipb\n";
        my $id = $oldpts->id($user);
        if(!$id) {
            warn "User $user doesn't exists in Athena cell?!";
            return;
        }
        if($pts->listentry($id)) {
            warn "UID $id already exists in SIPB cell, not creating!";
            return;
        }
        
        if(!$pts->createuser($user, $id)) {
            warn "Unable to create user: $user -c sipb\n";
            return;
        }
    }
    return 1;
}

sub looks_like_user {
    my $thing = shift;
    return $thing =~ m{^[\w\d_-]+(?:[.][\w\d_-]+)?$};
}

my @sync = read_list($synclist);
my %blacklist = map {$_=>1} read_list($blacklist);

for my $list (@sync) {
    my $afslist;
    my $member;
    my %sipb;
    my %athena;
    
    if($blacklist{$list}) {
        warn "Skipping blacklisted $list\n";
        next;
    }
    $afslist = "system:$list";
    if(!$athena->listentry($afslist)) {
        warn "No such list: $list\n";
        next;
    }
    %athena = map {$_=>1} $athena->members($afslist);

    create_list($sipb, $afslist) or next;

    %sipb = map {$_=>1} $sipb->members("$afslist");

    for $member (keys %athena) {
        if(!looks_like_user($member)) {
            warn "Skip non-user $member";
            next;
        }
        
        if(!$sipb{$member}) {
            warn "Add $member to $list";
        } else {
            next;
        }

        if(!create_user($sipb, $athena, $member)) {
            warn "Unable to create user $member in -c sipb";
            next;
        }

        if(!$sipb->adduser($member, $afslist)) {
            warn "Unable to add user $member to $list";
        }
    }

    for $member (keys %sipb) {
        if(!looks_like_user($member)) {
            warn "Skip non-user $member";
            next;
        }
        
        if(!$athena{$member}) {
            warn "Remove $member from $list\n";
        } else {
            next;
        }
        
        if(!$sipb->removeuser($member, $afslist)) {
            warn "Unable to remove user $member from $list";
        }
    }
}
