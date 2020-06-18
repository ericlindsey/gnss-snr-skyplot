#!/bin/bash

if [[ $# -lt 1 ]] ; then
  echo "Usage: $0 <sites>"
  echo " create timeseries plot from available files in the timeseries/ folder."
  exit 1
fi

source params.config

for site in $@
do 
  # do one year at a time to avoid files getting out of order. Repeat for years before and after 2000
  for yr in `seq -w 80 99`
  do
    if [[ "`echo snr/$site*.${yr}o.snr$snrtype`" != "snr/$site*.${yr}o.snr$snrtype" ]]; then
      echo gridding data from $yr
      ./grid_for_timeseries.sh `ls snr/$site*.${yr}o.snr$snrtype`
    fi
  done
  for yr in `seq -w 0 49`
  do
    if [[ "`echo snr/$site*.${yr}o.snr$snrtype`" != "snr/$site*.${yr}o.snr$snrtype" ]]; then
      echo gridding data from $yr
      ./grid_for_timeseries.sh `ls snr/$site*.${yr}o.snr$snrtype`
    fi
  done

done

