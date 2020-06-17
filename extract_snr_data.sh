#!/bin/bash

# convert all rinex files into SNR files

if [[ $# -lt 1 ]]; then
  echo " Usage: $0 <rinex files>"
  echo " extract SNR data from rinex files to the snr/ folder."
  exit 1
fi

source params.config

mkdir -p snr
mkdir -p sp3
# loop over all input rinex files, extract SNR by azimuth and elevation
for file in $@
do
  echo working on $file
  base=$(basename $file)
  site=${base:0:4}
  doy=${base:4:3}
  yr=${base:9:2}
  snrfile=snr/$base.snr$snrtype 

  # Check if the corresponding SNR file exists already, if not, create it.
  if [[ ! -f $snrfile ]]; then

    # get week and day of week from gamit 'doy' program
    # this requires gamit_globk to be installed (also required for getting the orbits)
    wk=`doy $yr $doy |awk 'NR==2{print $3}'`
    dow=`doy $yr $doy |awk 'NR==2{print $7}' | awk -F, '{print $1}'`
    sp3="sp3/igs${wk}${dow}.sp3"
    if [[ ! -f $sp3 ]]; then
        echo "expected orbit file $sp3 not found. Downloading from archive:"
        cd sp3
        #~/gg/com/sh_get_orbits -yr $yr -doy $doy -makeg no
        ~/gg/com/sh_get_orbits -orbit igsf -nofit -yr $yr -doy $doy
        cd ..
    fi
    
    echo "./gnssSNR/gnssSNR.e $file $snrfile $sp3 $snrtype"
    ./gnssSNR/gnssSNR.e $file $snrfile $sp3 $snrtype
  fi
done
