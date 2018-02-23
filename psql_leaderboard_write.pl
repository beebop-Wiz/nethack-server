use DBI;
use DBD::Pg;
use File::Temp qw(tempfile);
use strict;

my $dbh = DBI->connect("dbi:Pg:dbname=nethack", "", "", { RaiseError => 1, AutoCommit => 0 } );

my ($tfh1, $tfname1) = tempfile("/tmp/psqllbXXXXXX", UNLINK=>1);
my ($tfh2, $tfname2) = tempfile("/tmp/psqldfXXXXXX", UNLINK=>1);

`diff xlogfile /opt/nethack/nh360/var/xlogfile > $tfname1`;
`cat $tfname1 > discord_fifo`;
`cp /opt/nethack/nh360/var/xlogfile xlogfile`;
my $lcnt = 0;
while(<$tfh1>) {
    if($lcnt) {
	if(/> (.*)/) {
	    print $tfh2 "$1\n";
	}
	$lcnt--;
    } else {
	if(/[0-9]+a[0-9]+,([0-9]+)/) {
	    $lcnt = $1;
	} elsif(/[0-9]+a[0-9]+/) {
	    $lcnt = 1;
	}
    }
}

seek $tfh2, 0, 0;

my @log;
my $insert_sth = $dbh->prepare(<<EOQ);
INSERT INTO games VALUES ( DEFAULT, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?::bit, ?, ?, ?, ?, ?, ?, ?, to_timestamp(?), to_timestamp(?), ?::bit, ? );
EOQ

my %role_lookup = (
    'Arc' => 0,
    'Bar' => 1,
    'Cav' => 2,
    'Hea' => 3,
    'Kni' => 4,
    'Mon' => 5,
    'Pri' => 6,
    'Ran' => 7,
    'Rog' => 8,
    'Sam' => 9,
    'Tou' => 10,
    'Val' => 11,
    'Wiz' => 12
    );

my %race_lookup = (
    'Hum' => 0,
    'Elf' => 1,
    'Dwa' => 2,
    'Gno' => 3,
    'Orc' => 4
    );

my %align_lookup = (
    'Law' => 0,
    'Neu' => 1,
    'Cha' => 2
    );

my %gender_lookup = (
    'Mal' => 0,
    'Fem' => 1
    );

while(<$tfh2>) {
    print;
    my @fields_arr = split /\t/;
    my %F;
    foreach my $f (@fields_arr) {
	my @fa = split /=/, $f;
	$F{$fa[0]} = $fa[1];
    }
    $F{'conduct'} = hex $F{'conduct'};
    $F{'achieve'} = hex $F{'achieve'};
    $F{'death'} .= ", while " . $F{'while'} if exists $F{'while'};
    $insert_sth->execute(@F{'version', 'deathdnum', 'deathlev', 'maxlvl', 'hp', 'maxhp', 'points', 'deaths', 'deathdate', 'birthdate'}, $role_lookup{$F{'role'}}, $race_lookup{$F{'race'}}, $gender_lookup{$F{'gender'}}, $align_lookup{$F{'align'}}, @F{'name', 'death', 'conduct', 'turns', 'achieve', 'realtime', 'starttime', 'endtime'}, $gender_lookup{$F{'gender0'}}, $align_lookup{$F{'align0'}});
}


$dbh->commit;
$dbh->disconnect;
