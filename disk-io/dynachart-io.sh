#!/usr/bin/env bash

# usage: dynachart-io.sh Prod/csv

banner () {
	echo
	echo "====================================================================="
	echo "== $@"
	echo "====================================================================="
	echo
}


xlsxDir=xlsx

for csvFile in */csv/io-metrics.csv
do

	#banner "Processing $csvFile"
	baseFileName=$(basename $csvFile)
	baseDir=$(dirname $csvFile)
	baseDir=$(dirname $baseDir)
	mkdir -p $baseDir/$xlsxDir

	prefix=$(echo $baseFileName | cut -d'.' -f1)
	xlsFile=$baseDir/$xlsxDir/$prefix-$baseDir.xlsx

	banner "Converting $csvFile to $xlsFile"

	#cat <<-EOF
	dynachart.pl --spreadsheet-file $xlsFile --worksheet-col disk --category-col snaptime  \
		--chart-cols  phyrds \
		--chart-cols  phyblkrd \
		--chart-cols  phywrts \
		--chart-cols  phyblkwrt \
		--chart-cols  singleblkrds \
		--chart-cols  singleblkrdtim \
		--chart-cols  avgiotim \
		--chart-cols  readtim \
		--chart-cols  writetim \
		--chart-cols  miniotim \
		--chart-cols  maxiortm \
		--chart-cols  maxiowtm \
		--chart-cols  phyrdtimavg \
		--chart-cols  singleblkrdtimavg \
		--chart-cols  writetimavg \
		--chart-cols  avgreadsz \
		--chart-cols  avgwritesz \
		-- \
	< $csvFile
#EOF

done

