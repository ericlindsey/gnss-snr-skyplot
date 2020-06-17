#!/bin/bash

if [[ $# -lt 1 ]]; then 
  echo "Usage: $0 <snrfiles>"
  echo Plots all SNR values as points on a skymap.
  exit 1
fi

# azimuth/elevation resolution for plots
azincr=60
elincr=45

# which value to use
obs=S1

gmt makecpt -Cmagma -T20/50/1 -D -Z >magma_S1.cpt
gmt makecpt -Cmagma -T0/50/1 -D -Z >magma_S2.cpt

# combine all files and get just the az,el,snr values
rm -f temp_ungridded.dat
for snrfile in $@
do
  if [[ $obs == "S1" ]]; then
    awk '{print $3,$2,$7}' $snrfile >> temp_ungridded.dat 
  else
    awk '{print $3,$2,$8}' $snrfile >> temp_ungridded.dat 
  fi
done

# we assume the site name is the same for all files, use the first one
site=`echo $1 |cut -f2 -d/ | awk '{printf("%.4s\n",$1)}'`

#gmt blockmean temp_ungridded.dat -R0/360/0/85 -I$azincr/$elincr |gmt xyz2grd -R0/360/0/85 -I$azincr/$elincr -r -Gtemp_${site}_${obs}_$azincr-$elincr.grd

#make elevation-angle plot
gmt gmtset MAP_TICK_LENGTH -5p
gmt gmtset MAP_LABEL_OFFSET 15p
gmt gmtset FONT_TITLE 16p
gmt gmtset MAP_ANNOT_OFFSET_PRIMARY 10p
gmt gmtset PS_MEDIA A4

gmt psbasemap -R0/360/-90/0 -JS0/-90/3i -BWSEN+t"$site" -Bxa90f30g30 -Bya30f30g30 -P -K >  plots/${site}_${obs}_ungridded.ps

#gmt grd2xyz temp_${site}_${obs}_${azincr}-${elincr}.grd -s |awk -v az=$azincr -v el=$elincr '{printf("%f %f %f %f %fd %fd\n",$1,-$2,$3,0,el,az*cos($2*3.14159/180))}' |gmt psxy -SJ -Cmagma_$obs.cpt -R -J -O -K >>  plots/${site}_${obs}_ungridded.ps

awk '{print $1,-$2,$3}' temp_ungridded.dat |gmt psxy -Sp0.1c -Cmagma_${obs}.cpt -J -R -O -K >> plots/${site}_${obs}_ungridded.ps

gmt psscale  -Dx3.5i/0i+w3i/0.3i+e -Cmagma_${obs}.cpt -B10::/:"$obs SNR (dB)": -O -K >> plots/${site}_${obs}_ungridded.ps

gmt psxy -J -R -O -T >> plots/${site}_${obs}_ungridded.ps
gmt psconvert -A1p -Tg plots/${site}_${obs}_ungridded.ps
gs plots/${site}_${obs}_ungridded.ps

