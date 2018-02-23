#!/usr/bin/perl
use strict;
use Data::Dumper;

my $file;
open $file, "/opt/nethack/nh360/var/xlogfile";

my @log;

while(<$file>) {
    my @fields_arr = split /\t/;
    my %fields;
    foreach my $f (@fields_arr) {
	my @fa = split /=/, $f;
	$fields{$fa[0]} = $fa[1];
    }
    push @log, \%fields;
}

my @sorted_score = sort {$b->{'points'} <=> $a->{'points'}} @log;
my $total_games = @sorted_score;
@sorted_score = @sorted_score[0..49];

print <<EOHT;
<html><head><style type="text/css">table,th,td{border:1px solid black;border-collapse:collapse}th,td{padding:2px;}</style><title>NetHack Top 50</title></head>
<body><h1>NetHack Top 50</h1>
<a href="/">Go back</a>
Total games played: $total_games
<table style="border:1px solid black"><tr>
<th>
EOHT
print join("</th><th>", qw(Name Role Race Gender Align Points Turns D-Lvl (Max) Dungeon HP (Max) Cause));
print "</th></tr>";

foreach my $logline (@sorted_score) {
    next unless defined $logline;
    my %l = %$logline;
    print "<tr><td>";
    print join ("</td><td>", $l{"name"}, $l{"role"}, $l{"race"}, $l{"gender0"}, $l{"align0"}, $l{"points"}, $l{"turns"}, $l{"deathlev"}, $l{"maxlvl"}, ["The Dungeons of Doom", "Gehennom", "The Gnomish Mines", "The Quest", "Sokoban", "Fort Ludios", "Vlad's Tower", "The Elemental Planes"]->[$l{"deathdnum"}], $l{"hp"}, $l{"maxhp"}, $l{"death"});
    print "</td></tr>";
    print "\n";
}


print "</table></body></html>"
