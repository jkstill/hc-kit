#!/usr/bin/env bash


for csvFile in */csv/disk-io.csv
do

	csvDir=$(dirname $csvFile)
	ioMetricsFile="$csvDir/io-metrics.csv"

	echo "csvFile: $csvFile"
	echo " csvdir: $csvDir"
	echo " ioMetricsFile: $ioMetricsFile"

	time ./disk-io-collate.pl < $csvFile > $ioMetricsFile

done

