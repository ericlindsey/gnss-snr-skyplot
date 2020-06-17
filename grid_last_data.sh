#!/bin/bash

if [[ $# -lt 1 ]]; then
  echo " Usage: $0 <sites>"
  echo " create skyplots from extracted SNR data for each site"
  exit 1
fi

source params.config

# clear the elevation-averaged data
mkdir -p dat
rm -rf dat/*elevmean.dat

# loop over each supplied site name
for site in $@
do
  # get last 30 files, then use blockmean and xyz2grd to produce a grid
  echo gridding last 30 SNR values: $site
  ls -tr snr/$site????.??o.snr$snrtype | tail -n30 | xargs cat | awk -v obs=$obs 'obs=="S1" {print $3,$2,$7} obs=="S2" {print $3,$2,$8}' | gmt blockmean -r -R0/360/0/85 -C -I$azincr/$elincr -bo | gmt xyz2grd -bi -r -R0/360/0/85 -I$azincr/$elincr -Ggrd/${site}_${obs}_$azincr-$elincr.grd

  # average combined grid files by elevation
  gmt grd2xyz grd/${site}_${obs}_$azincr-$elincr.grd -s | gmt blockmean -r -C -R0/360/0/85 -I360/$elincr > dat/${site}_${obs}_elevmean.dat
done

