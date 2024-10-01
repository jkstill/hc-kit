
Health Check Kit
================

Scripts to use for gather oracle health check data when there is no direct access to the server.

Eventually there will be scripts for both Windows and Linux.

## Disk IO Metrics

The following assume you have access to a machine that allows access to the Oracle database as a DBA.

These scripts are so far all linux based.

They could be adapted to run via PowerShell on Windows, I just haven't done that yet.

If the database is using ASM for storage, see [ASM Metrics](https://github.com/jkstill/asm-metrics).

That is a more comprehensive source of data IO metrics, and does not require server access.

It does require the ability to login to ASM as a DBA.

Metrics can also be gathered from the oracle database, but will be limited to just that database.

Logging in to ASM allows collecting metrics for all databases on the server.



### collect disk IO metrics

```text
$ cd disk-io
$ nohup ./disk-io.pl --database myserver/orcl --username dba --password dba --iterations 1500 --sleep-seconds 60 --csv-file orcl-linux/csv/disk-io.csv --use-tbs-as-disk&
```

### Aggregate disk IO metrics

Used for charting in Excel.

#### disk-io-collate.sh

```bash
for csvFile in */csv/disk-io.csv
do

	csvDir=$(dirname $csvFile)
	ioMetricsFile="$csvDir/io-metrics.csv"

	echo "csvFile: $csvFile"
	echo " csvdir: $csvDir"
	echo " ioMetricsFile: $ioMetricsFile"

	time ./disk-io-collate.pl < $csvFile > $ioMetricsFile

done
```

#### create Excel with Charts

see [dynachart](https://github.com/jkstill/dynachart)

dynachart.sh:

```bash'
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

done
```

## CPU

Not yet available

## Network

Not yet available

## Memory

Not yet available


