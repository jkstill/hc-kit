#!/usr/bin/env perl

use warnings;
use strict;
use FileHandle;
use DBI;
use Getopt::Long;
use Data::Dumper;
use IO::Handle;
use File::Path qw(make_path);

my %optctl = ();

my($db, $username, $password);
my ($help, $sysdba, $connectionMode, $localSysdba, $sysOper) = (0,0,0,0,0);
my ($csvFile,$sleepSeconds,$iterations) = ('',60,1440);
my $useTbsAsDisk = 0;

Getopt::Long::GetOptions(
	\%optctl,
	"database=s" => \$db,
	"username=s" => \$username,
	"password=s" => \$password,
	"csv-file=s" => \$csvFile,
	"sleep-seconds=i"		=> \$sleepSeconds,
	"iterations=i"			=> \$iterations,
	"use-tbs-as-disk!"	=> \$useTbsAsDisk,
	"sysdba!"				=> \$sysdba,
	"local-sysdba!"=> \$localSysdba,
	"sysoper!"				=> \$sysOper,
	"z|h|help"				=> \$help
);

if (! $localSysdba) {

	$connectionMode = 0;
	if ( $sysOper ) { $connectionMode = 4 }
	if ( $sysdba ) { $connectionMode = 2 }

	usage(1) unless ($db and $username ); #and $password);
}


usage(0) if $help;

unless ( $csvFile ) {
	print "CSV file is required\n";
	usage(1);
}

my @dirChain = split(/\//, $csvFile);
pop @dirChain;
my $dir = join('/', @dirChain);
print "dir: $dir\n";
make_path $dir unless -d $dir;

#print qq{
#
#USERNAME: $username
#DATABASE: $db
#PASSWORD: $password
	 #MODE: $connectionMode
 #RPT LVL: @rptLevels
#};
#exit;


$|=1; # flush output immediately

my $dbh ;

if ($localSysdba) {
	$dbh = DBI->connect(
		'dbi:Oracle:',undef,undef,
		{
			RaiseError => 1,
			AutoCommit => 0,
			ora_session_mode => 2
		}
	);
} else {
	$dbh = DBI->connect(
		'dbi:Oracle:' . $db,
		$username, $password,
		{
			RaiseError => 1,
			AutoCommit => 0,
			ora_session_mode => $connectionMode
		}
	);
}

die "Connect to  $db failed \n" unless $dbh;
$dbh->{RowCacheSize} = 100;

my $diskSQL = q{substr(df.name, 1, instr(df.name,decode(instr(df.name,'/'),null,'\',0,'\','/'),1) -1) disk};

if ($useTbsAsDisk) {
	$diskSQL = q{ts.name disk};
}

my $sql=q{SELECT
   to_char(sysdate,'yyyy-mm-dd hh24:mi:ss') snaptime} . qq{\n, $diskSQL\n} . 
	q{, df.file#
   , df.name
   , fs.PHYRDS
   , fs.PHYBLKRD
   , fs.PHYWRTS
   , fs.PHYBLKWRT
   , fs.SINGLEBLKRDS
   , fs.SINGLEBLKRDTIM
   , fs.AVGIOTIM
   , fs.READTIM
   , fs.WRITETIM
   , fs.MINIOTIM
   , fs.MAXIORTM
   , fs.MAXIOWTM
   , round((fs.phyblkrd / decode(fs.phyblkwrt,0,1,fs.phyblkwrt)),2) rw_ratio
   , global_name
from v$datafile df
	, v$filestat fs
	, global_name g
	, v$tablespace ts
where df.file#=fs.file#
	and ts.ts# = df.ts#};

my $sth = $dbh->prepare($sql,{ora_check_sql => 0});
$sth->execute;


my @columns = @{$sth->{NAME_lc}};

my $printHeader = 1;
if (-e $csvFile) {
	$printHeader = 0;
}

open my $fh, '>>', $csvFile or die "Could not open file '$csvFile' $!";
$fh->autoflush(1);

print $fh join(',', @columns) . "\n" if $printHeader;

foreach my $i (1..$iterations) {
	$sth->execute;

	while (my $row = $sth->fetchrow_arrayref) {
		print $fh join(',', @{$row}) . "\n";
	}

	warn "Sleeping for $sleepSeconds seconds\n";
	sleep $sleepSeconds unless $i == $iterations;

}

$fh->close;
$sth->finish;
$dbh->disconnect;

sub usage {
	my $exitVal = shift;
	$exitVal = 0 unless defined $exitVal;
	use File::Basename;
	my $basename = basename($0);
	print qq/

usage: $basename

  -database		     target instance
  -username		     target instance account name
  -password		     target instance account password
  -csv-file         output file
  -sleep-seconds    sleep time between snapshots
  -iterations	     number of snapshots to take
  -use-tbs-as-disk  use tablespace name as disk name - the label will still be 'disk'
  -sysdba		     logon as sysdba
  -sysoper		     logon as sysoper
  -local-sysdba     logon to local instance as sysdba. ORACLE_SID must be set
					     the following options will be ignored:
						   -database
						   -username
						   -password

  example:

  $basename -database dv07 -username scott -password tiger -sysdba

  $basename -local-sysdba

/;
	exit $exitVal;
};


