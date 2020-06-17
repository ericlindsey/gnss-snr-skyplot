#!/bin/bash

if [[ $# -lt 1 ]]; then 
  echo "Usage: $0 <snrfiles>"
  echo "Use blockmean to grid all SNR files and output as timeseries files"
  exit 1
fi

source params.config

for snrfile in $@
do
  # get site name and decimal year from filename
  base=$(basename $snrfile)
  site=${base:0:4}
  doy=${base:4:3}
  yr=${base:9:2}
  decyr=`doy $yr $doy |awk 'NR==3{print $3}'`

  # grid data
  awk -v obs=$obs 'obs=="S1" {print $3,$2,$7} obs=="S2" {print $3,$2,$8}' $snrfile |gmt blockmean -r -R0/360/0/85 -I$ts_azincr/$ts_elincr -bo | gmt xyz2grd -bi -r -R0/360/0/85 -I$ts_azincr/$ts_elincr -G$snrfile.$obs.grd

  # extract data back out of .grd and write time/value pairs for each az/el value
  gmt grd2xyz $snrfile.$obs.grd > $snrfile.$obs.dat
  while read -r line
  do 
    az=`echo $line |awk '{print $1}'`
    el=`echo $line |awk '{print $2}'`
    val=`echo $line |awk '{print $3}'`
    # note, values are appended - delete the file manually to start over
    if [[ ! -f timeseries/$site-$obs-$az-$el.dat ]]; then
      # add header to the start of the file if it does not exist already
      NR12=`echo $NR | awk '{print $1%12}'`
      echo "> -Z$NR12" > timeseries/$site-$obs-$az-$el.dat
    fi
    NR=$(expr $NR + 1)
    echo $decyr $val >> timeseries/$site-$obs-$az-$el.dat
  done < $snrfile.$obs.dat
done

