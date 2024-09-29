#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;


=head1 Data Transformation

 use the data provided by disk-io.pl, and collate/collapse to disk, metric per period

 Sample Data:

 snaptime,disk,file#,name,phyrds,phyblkrd,phywrts,phyblkwrt,singleblkrds,singleblkrdtim,avgiotim,readtim,writetim,miniotim,maxiortm,maxiowtm,rw_ratio,global_name
 2024-09-19 17:54:01,E:,1,E:\ORADATA\RENI2\DATAFILE\SYSTEM01.DBF,4654064,21971851,490416,736017,3645678,89594,0,243840,261309,0,146,102,29.85,RENI2.RENINC.COM
 2024-09-19 17:54:01,J:,2,J:\ORADATA\RENI2\DATAFILE\SYSAUX01.DBF_NEW,4271463,89762507,417337,708662,1980621,43826,0,1606459,153686,0,102,64,126.66,RENI2.RENINC.COM


 the metrics are accumulative.  
 some must be have the previous value subtracted from them

 phyrds for instance.
 the number of reads since the previous snap is current - previous value

 
 Column  Description
 FILE# Number of the file
 PHYRDS Number of physical reads done
 PHYWRTS Number of times DBWR is required to write
 PHYBLKRD Number of physical blocks read
 OPTIMIZED_PHYBLKRD Number of physical reads from Database Smart Flash Cache blocks
 PHYBLKWRT Number of blocks written to disk, which may be the same as PHYWRTS if all writes are single blocks
 SINGLEBLKRDS Number of single block reads 
 READTIM Time (in hundredths of a second) spent doing reads if the TIMED_STATISTICS parameter is true; 0 if false 
 WRITETIM Time (in hundredths of a second) spent doing writes if the TIMED_STATISTICS parameter is true; 0 if false
 SINGLEBLKRDTIM Cumulative single block read time (in hundredths of a second)
 AVGIOTIM Average time (in hundredths of a second) spent on I/O, if the TIMED_STATISTICS parameter is true; 0 if false
 LSTIOTIM Time (in hundredths of a second) spent doing the last I/O, if the TIMED_STATISTICS parameter is true; 0 if false
 MINIOTIM Minimum time (in hundredths of a second) spent on a single I/O, if the TIMED_STATISTICS parameter is true; 0 if false
 MAXIORTM Maximum time (in hundredths of a second) spent doing a single read, if the TIMED_STATISTICS parameter is true; 0 if false
 MAXIOWTM Maximum time (in hundredths of a second) spent doing a single write, if the TIMED_STATISTICS parameter is true; 0 if false 
 
 CON_ID The ID of the container to which the data pertains. Possible values include: 
   0: This value is used for rows containing data that pertain to the entire CDB. This value is also used for rows in non-CDBs.
   1: This value is used for rows containing data that pertain to only the root
   n: Where n is the applicable container ID for the rows containing data

=cut

# overhead between snaps is about 1 second
# snaps are 61 seconds apart
# calling it 60 seconds here. though not quite accurate, it is close enough to analyzing disk io from the database
my $intervalSeconds=60;

# snaptime,disk,file#,name,phyrds,phyblkrd,phywrts,phyblkwrt,singleblkrds,singleblkrdtim,avgiotim,readtim,writetim,miniotim,maxiortm,maxiowtm,rw_ratio,global_name

# not getting rw_ratio
my ($metricPosLow, $metricPosHigh) = (4,15);

#print Dumper(\@metricNames);
#exit;

my $verbose = 0;

my %rawIoMetrics = ();
my @snapTimes=();
my $metricsFormat = '%0.6f';

my $hdr=<STDIN>;
chomp $hdr;
my @hdr=split(/,/,$hdr);
my @metricNames = @hdr[$metricPosLow .. $metricPosHigh];
my $i=0;
my %metricPositions = map{ $_ => $i++ } @metricNames;

#warn '@metricNames: ' . Dumper(\@metricNames);
#warn '%metricPositions: ' . Dumper(\%metricPositions);
#exit;

while (my $line = <STDIN>) {

	chomp $line;
	my @rawData=split(/,/,$line);
	my ($snapTime,$disk,$fileNum,$fileName) = @rawData;

	$disk =~ s/://;

	print qq {

    snaptime: $snapTime
        disk: $disk
       file#: $fileNum
    fileName: $fileName

} if $verbose;

	push @snapTimes, $snapTime unless grep (/^$snapTime/,@snapTimes);
	print ' @snapTimes: ' . Dumper(\@snapTimes) if $verbose;

	#print '@rawData: ' . Dumper(\@rawData) if $verbose;
	my @metrics=@rawData[$metricPosLow .. $metricPosHigh];

	print Dumper(\@metrics) if $verbose;
	
	# these are enough to ensure uniqueness
	# disk not needed for uniqueness, but is needed later
	$rawIoMetrics{$snapTime}{$disk}{$fileNum}=\@metrics;
}

# print '$rawIoMetrics: ' . Dumper(\%rawIoMetrics);

# key will be snaptime and disk
my %ioMetrics=();

# sacrifice the first set of data to calculate the others
my $snapTimePrev = shift @snapTimes;
#warn "snapTimePrev: $snapTimePrev\n";


#print '@snapTimes: ' . Dumper(\@snapTimes) ; #$if $verbose;
#exit;

$i=0;
foreach my $snapTime ( @snapTimes ) {

	#warn "snapTime: $snapTime\n";
	last if $i++ >= $#snapTimes;


	# get the priors
	my %dataPrev = %{processMetrics($snapTimePrev)};

	my %dataCurr = %{processMetrics($snapTime)};

	# populate the final data
	#print '%dataPrev: ' . Dumper(\%dataPrev) ; #if $verbose;
	#print '%dataCurr: ' . Dumper(\%dataCurr) ; #if $verbose;

	#foreach my $disk	( keys %{$dataCurr{$snapTime}} ) {
	foreach my $disk	( keys %dataCurr ) {
		#print "  disk: $disk\n" ; #if $verbose;
		foreach my $metricName (@metricNames) {
			         # no calc on avgiotim,miniotim,maxiortm,maxiowtm -  these not a deltas
         # they are averages or max/min values
         if ($metricName =~ /^(avgiotim|miniotim|maxiortm|maxiowtm)$/ ) {
				#warn "setting $metricName to $dataCurr{$disk}{$metricName}\n";
            $ioMetrics{$snapTime}{$disk}{$metricName} = $dataCurr{$disk}{$metricName};
         } else {
            $ioMetrics{$snapTime}{$disk}{$metricName} =  $dataCurr{$disk}{$metricName} - $dataPrev{$disk}{$metricName};
         }
		}
	}
	#exit;

	$snapTimePrev = $snapTime;
}

#print '%ioMetrics: ' . Dumper(\%ioMetrics);
#exit;

# now add some calculations
# snaptime,disk,file#,name,phyrds,phyblkrd,phywrts,phyblkwrt,singleblkrds,singleblkrdtim,avgiotim,readtim,writetim,miniotim,maxiortm,maxiowtm,rw_ratio,global_name
push @metricNames,qw(phyrdtimavg singleblkrdtimavg writetimavg avgreadsz avgwritesz);

# assume 8192 blocks
my $blksz=8192;

#print Dumper(\%ioMetrics);
#exit;

foreach my $snapTime (@snapTimes) {
	#print "snapTime2: $snapTime\n";
	foreach my $disk	( keys %{$ioMetrics{$snapTime}} ) {
		$ioMetrics{$snapTime}{$disk}{phyrdtimavg} = $ioMetrics{$snapTime}{$disk}{phyrds} > 0 ? $ioMetrics{$snapTime}{$disk}{readtim} /  $ioMetrics{$snapTime}{$disk}{phyrds} : 0;
		$ioMetrics{$snapTime}{$disk}{singleblkrdtimavg} = $ioMetrics{$snapTime}{$disk}{singleblkrds} > 0 ? $ioMetrics{$snapTime}{$disk}{singleblkrdtim} /  $ioMetrics{$snapTime}{$disk}{singleblkrds} : 0;
		$ioMetrics{$snapTime}{$disk}{writetimavg} = $ioMetrics{$snapTime}{$disk}{phywrts} > 0 ? $ioMetrics{$snapTime}{$disk}{writetim} /  $ioMetrics{$snapTime}{$disk}{phywrts} : 0;

		# convert from centiseconds to seconds
		foreach my $metricName ( qw(phyrdtimavg singleblkrdtim readtim writetim singleblkrdtimavg writetimavg miniotim maxiortm maxiowtm avgiotim)) {
			$ioMetrics{$snapTime}{$disk}{$metricName} = sprintf($metricsFormat, $ioMetrics{$snapTime}{$disk}{$metricName} / 100);
		}

		$ioMetrics{$snapTime}{$disk}{avgwritesz} = $ioMetrics{$snapTime}{$disk}{phywrts} > 0 ? $ioMetrics{$snapTime}{$disk}{phyblkwrt} /  $ioMetrics{$snapTime}{$disk}{phywrts} : 0;
		$ioMetrics{$snapTime}{$disk}{avgwritesz} = sprintf('%0d', $ioMetrics{$snapTime}{$disk}{avgwritesz} * $blksz);

		$ioMetrics{$snapTime}{$disk}{avgreadsz} = $ioMetrics{$snapTime}{$disk}{phyrds} > 0 ? $ioMetrics{$snapTime}{$disk}{phyblkrd} /  $ioMetrics{$snapTime}{$disk}{phyrds} : 0;
		$ioMetrics{$snapTime}{$disk}{avgreadsz} = sprintf('%0d', $ioMetrics{$snapTime}{$disk}{avgreadsz} * $blksz);

		#print "$snapTime,$disk," .  join(',', map { $ioMetrics{$snapTime}{$disk}->{$_} } @metricNames )  . "\n";
	}
}


#warn Dumper(\%ioMetrics);

#splice(@hdr,$metricPosHigh,0,qw(phyrdtimavg singleblkrdtimavg writetimavg));
#print join(',',@hdr) . "\n";

print 'snaptime,disk,' . join(',',@metricNames) . "\n";
#exit;

foreach my $snapTime (@snapTimes) {
	#print "snapTime: $snapTime\n";
	foreach my $disk	( sort keys %{$ioMetrics{$snapTime}} ) {
		#print "  disk: $disk\n";
		print "$snapTime,$disk," .  join(',', map { $ioMetrics{$snapTime}{$disk}->{$_} } @metricNames )  . "\n";
	}
}

#warn Dumper(\@metricNames);

sub processMetrics {
	my ($snapTime) = @_;
	

	my %data=();


	foreach my $disk	( keys %{$rawIoMetrics{$snapTime}} ) {

		warn "  prev disk: $disk\n" if $verbose;

		my ($miniotimPrev, $maxiortmPrev, $maxiowtmPrev) = (99999999999,0,0);

		# capture min/max times per disk and snaptime
		my %minMaxTimes = ();

		my $fileCount=1;
		foreach my $fileNum ( keys  %{$rawIoMetrics{$snapTime}{$disk}} ) {
			#print "    filenum: $fileNum\n";
			my @testData = @{$rawIoMetrics{$snapTime}{$disk}{$fileNum}};
			#print '@testDataPrev: ' . Dumper(\@testData);

			#foreach my $metricName ( qw( phyrds phyblkrd phywrts phyblkwrt singleblkrds singleblkrdtim readtim writetim avgiotim)) {
			foreach my $metricName ( qw( phyrds phyblkrd phywrts phyblkwrt singleblkrds singleblkrdtim readtim writetim)) {
				$data{$disk}{$metricName} += $testData[$metricPositions{$metricName}];
			}
			
			#print '%data ' . Dumper(\%data) ;#if $verbose;

			# miniotim is always zero in the source data - perhaps a bug in v$filestat
			my $miniotim= $testData[$metricPositions{miniotim}];
			$miniotim = $miniotim < $miniotimPrev ? $miniotim : $miniotimPrev;

			my $maxiortm = $testData[$metricPositions{maxiortm}];
			#warn "==========\nmaxiortm: $maxiortm\n";
			$maxiortm = $maxiortm > $maxiortmPrev ? $maxiortm : $maxiortmPrev;
			#warn "   maxiortm: $maxiortm\n";

			my $maxiowtm = $testData[$metricPositions{maxiowtm}];
			$maxiowtm = $maxiowtm > $maxiowtmPrev ? $maxiowtm : $maxiowtmPrev;

			$minMaxTimes{$disk}{miniotim} = $miniotim;
			$minMaxTimes{$disk}{maxiortm} = $maxiortm;
			$minMaxTimes{$disk}{maxiowtm} = $maxiowtm;
			map { $minMaxTimes{$disk}{avgiotim} += $data{$disk}{$_} } qw(singleblkrdtim readtim writetim);
			map { $minMaxTimes{$disk}{ios} += $data{$disk}{$_} } qw(singleblkrds phyrds phywrts);


			($miniotimPrev, $maxiortmPrev, $maxiowtmPrev) = ($miniotim, $maxiortm, $maxiowtm);

			$fileCount++;
		}
			
		#warn "       maxiortm: $minMaxTimes{$disk}{maxiortm}\n";

		$data{$disk}{miniotim} = $minMaxTimes{$disk}{miniotim};
		$data{$disk}{maxiortm} = $minMaxTimes{$disk}{maxiortm};
		$data{$disk}{maxiowtm} = $minMaxTimes{$disk}{maxiowtm};
		$data{$disk}{avgiotim} = $minMaxTimes{$disk}{avgiotim} / $minMaxTimes{$disk}{ios} / $fileCount;

	}

	return \%data;
}



