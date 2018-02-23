#!/usr/bin/perl
use DBI;
use DBD::Pg;
use POSIX;
use strict;
use warnings;
no if $] >= 5.017011, warnings => 'experimental::smartmatch'; # why

my %get;
my $getstr = "";
my @get_passthrough = qw(view user);
while(<>) {
    my @a = split /=/;
    chomp $a[1];
    $get{$a[0]} = $a[1];
#    print "`$a[0]', `$a[1]'\n";
}

foreach my $key (keys %get) {
    $getstr .= "&$key=$get{$key}" if($key ~~ @get_passthrough);
}


my $dbh = DBI->connect("dbi:Pg:dbname=nethack", "beebop", "", { RaiseError => 1, AutoCommit => 0 } );
my $view;

if(exists $get{"view"}) {
    $view = $get{"view"};
} else {
    $view = "score";
}

if($view eq "stats") {

    my $user = 0;
    my $forstr = "";
    if(exists $get{"user"}) {
	$user = $get{"user"};
	$forstr = " for $user" if length $user;
    }
    
    my $select_sums;
    if($user) {
	$select_sums = $dbh->prepare("SELECT SUM(points),SUM(turns),COUNT(*) FROM games WHERE name = ?");
    } else {
	$select_sums = $dbh->prepare("SELECT SUM(points),SUM(turns),COUNT(*) FROM games");
    }
    if($user) {
	$select_sums->execute($user);
    } else {
	$select_sums->execute();
    }
    my @row = $select_sums->fetchrow_array;
    my $ngames = $row[2];
    my $pts_avg = $row[0] / $row[2];
    print <<EOHTML;
<html><head><title>NetHack Statistics</title></head>
<body><h1>NetHack Statistics$forstr</h1>
<a href="/">Go back</a><br>
<a href="/leaderboard?view=score">Leaderboard</a> | Statistics
<form action="/leaderboard" method="get"> Username: <input name="user" type="text"> <input name="view" type="hidden" value="stats"> <input type="submit" value="View user"> </form>
    <h3> Totals </h3>
    Total games: $row[2] <br>
    Total points: $row[0] <br>
    Average points: $pts_avg <br>
    Total turns: $row[1] <br>
    <h3> Achievements </h3>
EOHTML
    
    my $select_achieve;
    if($user) {
	$select_achieve = $dbh->prepare("SELECT COUNT(*) FROM games WHERE (achieve & ?) != 0 AND name = ?");
    } else {
	$select_achieve = $dbh->prepare("SELECT COUNT(*) FROM games WHERE (achieve & ?) != 0");
    }

    my %achievements = (
	0x001 => "got the Bell of Opening",
	0x002 => "entered Gehennom",
	0x004 => "got the Candelabrum of Invocation",
	0x008 => "got the Book of the Dead",
	0x010 => "performed the Invocation",
	0x020 => "got the Amulet of Yendor",
	0x040 => "reached the Elemental Planes",
	0x080 => "reached the Astral Plane",
	0x100 => "ascended to demigod-hood",
	0x200 => "got the luckstone at Mine's End",
	0x400 => "finished Sokoban",
	0x800 => "killed Medusa"
    );
    
    foreach my $k(sort {$a <=> $b} keys %achievements) {
	if($user) {
	    $select_achieve->execute($k, $user);
	} else {
	    $select_achieve->execute($k);
	}
	my @r = $select_achieve->fetchrow_array;
	if($ngames) {
	    my $pct = sprintf("%.4f", $r[0] * 100.0 / $ngames);
	    print "$r[0] (${pct}%) $achievements{$k} <br>\n";
	}
    }

    print "<h3> Conduct </h3>";
    
    my $select_ce_count;
    if($user) {
	$select_ce_count = $dbh->prepare("SELECT COUNT(*) FROM games WHERE turns > 1000 AND name = ?");
	$select_ce_count->execute($user);
    } else {
	$select_ce_count = $dbh->prepare("SELECT COUNT(*) FROM games WHERE turns > 1000");
	$select_ce_count->execute;
    }
    my $ncg = $select_ce_count->fetchrow_arrayref->[0];

    print "Out of $ncg games lasting over 1000 turns:<br>\n";

    my $select_conduct;
    if($user) {
	$select_conduct = $dbh->prepare("SELECT COUNT(*) FROM games WHERE (conduct & ?) != 0 AND turns > 1000 AND name = ?");
    } else {
	$select_conduct = $dbh->prepare("SELECT COUNT(*) FROM games WHERE (conduct & ?) != 0 AND turns > 1000");
    }

    my %conducts = (
	0x001 => "went without food",
	0x002 => "followed a strict vegan diet",
	0x004 => "were vegetarian",
	0x008 => "were atheist",
	0x010 => "never hit with a wielded weapon",
	0x020 => "were pacifist",
	0x040 => "were illiterate",
	0x080 => "never polymorphed an object",
	0x100 => "never changed form",
	0x200 => "used no wishes",
	0x400 => "never wished for an artifact",
	0x800 => "never genocided any mosters"
	);
    
    foreach my $k(sort {$a <=> $b} keys %conducts) {
	if($user) {
	    $select_conduct->execute($k, $user);
	} else {
	    $select_conduct->execute($k);
	}
	my @r = $select_conduct->fetchrow_array;
	if($ncg) {
	    my $pct = sprintf("%.4f", $r[0] * 100.0 / $ncg);
	    print "$r[0] (${pct}%) $conducts{$k} <br>\n";
	}
    }
} else {
    my ($offt, $count, $user, $forstr);
    $forstr = "";
    if(exists $get{"count"} && $get{"count"} < 51) {
	$count = int($get{"count"});
    } else {
	$count = 50;
    }
    
    if(exists $get{"page"}) {
	$offt = int($get{"page"});
    } else {
	$offt = 1;
    }

    if(exists $get{"user"}) {
	$user = $get{"user"};
	$forstr = " for $user" if length $user;
    } else {
	$user = 0;
    }

    my $select_total;
    if($user) {
	$select_total = $dbh->prepare("SELECT COUNT(*) FROM games WHERE name = ?");
	$select_total->execute($user);
    } else {
	$select_total = $dbh->prepare("SELECT COUNT(*) FROM games");
	$select_total->execute;
    }	
    my $ngames = $select_total->fetchrow_arrayref->[0];
    my $npages = ceil($ngames / $count);
    if($offt > $npages) {
	$offt = $npages;
    }
    if($offt < 1) {
	$offt = 1;
    }

    my $select_sth;
    if($user) {
	$select_sth = $dbh->prepare("SELECT * FROM games WHERE name = ? ORDER BY points DESC LIMIT ? OFFSET ?");
	$select_sth->execute($user, $count, ($offt - 1) * $count);
    } else {
	$select_sth = $dbh->prepare("SELECT * FROM games ORDER BY points DESC LIMIT ? OFFSET ?");
	$select_sth->execute($count, ($offt - 1) * $count);
    }
    
    print <<EOHTML;
<html><head><style type="text/css">table,th,td{border:1px solid black;border-collapse:collapse}th,td{padding:2px;}</style><title>NetHack Leaderboard</title></head>
<body><h1>NetHack Leaderboard$forstr</h1>
<a href="/">Go back</a><br>
Leaderboard | <a href="/leaderboard?view=stats">Statistics</a><br>
<form action="/leaderboard" method="get"> Username: <input name="user" type="text"> <input name="view" type="hidden" value="score"> <input type="submit" value="View user"> </form>
EOHTML

    print "Showing $count of $ngames games, page $offt of $npages\n";
    if($offt > 1) {
	print " <a href='/leaderboard?page=" . ($offt - 1) . "$getstr'>Prev</a>";
    } else {
	print "Prev";
    }
    print " | ";
    if($offt < $npages) {
	print " <a href='/leaderboard?page=" . ($offt + 1) . "$getstr'>Next</a>";
    } else {
	print "Next";
    }
    print "<br>\n";
    print "<table>\n<tr><th>\n";
	
    my %role_lookup = (
	0 => 'Arc',
	1 => 'Bar',
	2 => 'Cav',
	3 => 'Hea',
	4 => 'Kni',
	5 => 'Mon',
	6 => 'Pri',
	7 => 'Ran',
	8 => 'Rog',
	9 => 'Sam',
	10 => 'Tou',
	11 => 'Val',
	12 => 'Wiz'
	);

    my %race_lookup = (
	0 => 'Hum',
	1 => 'Elf',
	2 => 'Dwa',
	3 => 'Gno',
	4 => 'Orc'
	);

    my %align_lookup = (
	0 => 'Law',
	1 => 'Neu',
	2 => 'Cha'
	);

    my %gender_lookup = (
	0 => 'Mal',
	1 => 'Fem'
	);

    my %dungeons = (
	0 => 'The Dungeons of Doom',
	1 => 'Gehennom',
	2 => 'The Gnomish Mines',
	3 => 'The Quest',
	4 => 'Sokoban',
	5 => 'Fort Ludios',
	6 => 'Vlad\'s Tower',
	7 => 'The Elemental Planes'
	);

    print join("</th><th>", qw(Name Start Role Race Gender Align Points Turns D-Lvl (Max) Dungeon HP (Max) Death));
    print "</th></tr>";
    
    my $row;
    while($row = $select_sth->fetchrow_hashref) {
	print "<tr><td>";
	$$row{'role'} = $role_lookup{$$row{'role'}};
	$$row{'race'} = $race_lookup{$$row{'race'}};
	$$row{'gender'} = $gender_lookup{$$row{'gender'}};
	$$row{'align'} = $align_lookup{$$row{'align'}};
	$$row{'gender0'} = $gender_lookup{$$row{'gender0'}};
	$$row{'align0'} = $align_lookup{$$row{'align0'}};
	$$row{'deathdnum'} = $dungeons{$$row{'deathdnum'}};
	print join "</td><td>", @$row{'name', 'starttime', 'role', 'race', 'gender0', 'align0', 'points', 'turns', 'deathlev', 'maxlvl', 'deathdnum', 'hp', 'maxhp', 'death'};
	print "</td></tr>\n";
    }
    
    print "</table></body></html>\n";
}

$dbh->disconnect;
