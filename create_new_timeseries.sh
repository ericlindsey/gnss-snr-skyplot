#!/bin/bash

if [[ $# -lt 1 ]] ; then
  echo "Usage: $0 <sites>"
  echo " create timeseries plot from available files in the timeseries/ folder."
  exit 1
fi

#new timeseries: just delete existing timeseries and then run update.

for site in $@
do 
  rm -f timeseries/$site*
done

./update_timeseries.sh $@

