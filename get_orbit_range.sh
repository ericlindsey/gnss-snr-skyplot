#!/bin/bash

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <wk1> <wk2>"
  echo "downloads SOPAC orbits for all days in the week range specified"
  exit 1
fi

startweek=$1
endweek=$2

for wk in `seq $startweek $endweek`
do
  if [[ ! -f igs${wk}6.sp3 ]]; then
    echo wget ftp://anonymous:user%40host.edu@garner.ucsd.edu/pub/products/$wk/igs$wk?.sp3.Z
    wget ftp://anonymous:user%40host.edu@garner.ucsd.edu/pub/products/$wk/igs$wk?.sp3.Z
    gunzip igs$wk?.sp3.Z
  fi
done

