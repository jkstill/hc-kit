#!/usr/bin/env bash


for csvFile in */csv/disk-io.csv
do

	csvDir=$(dirname $csvFile)
	ioMetricsFile="$csvDir/io-metrics-reference.csv"

	echo "csvFile: $csvFile"
	echo " csvdir: $csvDir"
	echo " ioMetricsFile: $ioMetricsFile"

	#chmod u+w $ioMetricsFile

	time ./disk-io-collate.pl < $csvFile > $ioMetricsFile

	chmod -w $ioMetricsFile

done

