#!/bin/bash

# convert all rinex files into SNR files

if [[ $# -lt 1 ]]; then
  echo " Usage: $0 <rinex files>"
  echo " converts SNR data from rinex files to a series of sky-plots."
  exit 1
fi

gmt gmtset PS_MEDIA A0

# azimuth/elevation resolution for plots
azincr=10
elincr=5
# azimuth/elevation resolution for timeseries
ts_azincr=60
ts_elincr=45

# set SNR type:
# 77 = only L2C satellites
# 88 = all data
# 99 = only data between 5 and 30 degree elevation angles
snrtype=88

#choose observable: S1 or S2
obs=S1

mkdir -p snr
mkdir -p sp3
mkdir -p grd
mkdir -p dat
mkdir -p ts_grd
rm -f ts_grd/*
mkdir -p plots
rm -f snrlist.txt
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

  # grid each day, for timeseries
  if [[ $obs == "S1" ]]; then
    awk '{print $3,$2,$7}' $snrfile > temp.dat 
  else
    awk '{print $3,$2,$8}' $snrfile > temp.dat 
  fi
  gmt blockmean temp.dat -R0/360/0/85 -I$ts_azincr/$ts_elincr |gmt xyz2grd -R0/360/0/85 -I$ts_azincr/$ts_elincr -r -Gts_grd/${site}_${yr}_${doy}_S1_$ts_azincr-$ts_elincr.grd

  # add snr file to list of those processed in this batch
  echo $snrfile >> snrlist.txt
done

gmt makecpt -Cmagma -T20/50/1 -D -Z >magma_S1.cpt
gmt makecpt -Cmagma -T0/50/1 -D -Z >magma_S2.cpt
gmt makecpt -Cpolar -T-10/10/1 -D -Z >polar10.cpt

# get list of unique 4-character site names
cut snrlist.txt -f2 -d/ | awk '{printf("%.4s\n",$1)}' |uniq > siteslist.txt

# average SNR output to single GMT grid files for each site
for site in `cat siteslist.txt`
do
  echo gridding last 30 SNR values: $site
  rm -f snr/$site.snr$snrtype
  for recent in `ls -tr snr/$site????.??o.snr$snrtype |tail -n30`
  do
     cat $recent >> snr/$site.snr$snrtype
  done
  if [[ $obs == "S1" ]]; then
    awk '{print $3,$2,$7}' snr/$site.snr$snrtype > temp.dat 
  else 
    awk '{print $3,$2,$8}' snr/$site.snr$snrtype > temp.dat 
  fi
  gmt blockmean temp.dat -R0/360/0/85 -I$azincr/$elincr |gmt xyz2grd -R0/360/0/85 -I$azincr/$elincr -Ggrd/${site}_S1_$azincr-$elincr.grd
done

# make timeseries and plots
# delete any data for this site
mkdir -p timeseries
for site in `cat siteslist.txt`
do 
  echo making timeseries for $site
  rm -rf timeseries/$site*
  for file in `ls ts_grd/${site}_*_${obs}_$ts_azincr-$ts_elincr.grd`
  do
    # get one point per day per grid point and add to plot? lots of plotting commands!
    # or, extract all points and issue one command?

    #get decimal yr - fragile method
    yr=${file:12:2}
    doy=${file:15:3}
    decyr=`doy $yr $doy |awk 'NR==3{print $3}'`

    #simplistic method: convert to an xyz file, then move each line to the correct timeseries file
    NR=0
    echo $file
    gmt grd2xyz $file > temp.dat
    while read line
    do
      #count line
      # get each value from this line as a variable
      az=`echo $line |awk '{print $1}'`
      el=`echo $line |awk '{print $2}'`
      value=`echo $line |awk '{print $3}'`
      if [[ ! -f timeseries/$site-$obs-$az-$el.dat ]]; then
        # add header to the start of the file if it does not exist already
        NR12=`echo $NR | awk '{print $1%12}'`
        echo "> -Z$NR12" > timeseries/$site-$obs-$az-$el.dat
      fi
      NR=$(expr $NR + 1)
      echo $decyr $value >> timeseries/$site-$obs-$az-$el.dat
    done < temp.dat
  done

done

#rm -f plots/*.ps
#rm -f temp.dat

