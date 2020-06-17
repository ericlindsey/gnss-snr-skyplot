#!/bin/bash

if [[ $# -lt 1 ]]; then
  echo " Usage: $0 <sites>"
  echo " create skyplots from extracted SNR data for each site"
  exit 1
fi

source params.config

# first run gridding commands for each site
./grid_last_data.sh $@

# combine all averaged files to get the network average SNR by elevation
cat dat/????_${obs}_elevmean.dat | gmt blockmean -r -C -R0/360/0/85 -I360/$elincr |awk '{print $2,$3}' > dat/all_${obs}_elevmean.dat
# create synthetic grd with uniform values in azimuth
rm -f temp_elevmean.dat
startaz=`echo $azincr |awk '{print $1/2}'`
for x in `seq $startaz $azincr 360`
do
  awk -v x=$x '{print x,$1,$2}' dat/all_${obs}_elevmean.dat >> temp_elevmean.dat
done
gmt xyz2grd temp_elevmean.dat -r -R0/360/0/85 -I$azincr/$elincr -Ggrd/${obs}_elevmean.grd

#make elevation-angle plots
gmt gmtset MAP_TICK_LENGTH -5p
gmt gmtset MAP_LABEL_OFFSET 15p
gmt gmtset FONT_TITLE 16p
gmt gmtset MAP_ANNOT_OFFSET_PRIMARY 9p
gmt gmtset PS_MEDIA A4

for site in $@
do
  #make elevation plots
  SITE=`echo $site | tr [:lower:] [:upper:]`
  awk '{print $2,$3}' dat/${site}_${obs}_elevmean.dat | gmt psxy -R0/85/0/60 -JX5i/3i -X1i -Y5i -Ba10f5:"Elevation Angle":/a10f5:"GPS SNR (dB)"::."Site ${SITE}":WSen -W1p,red -P -K > plots/${site}_elevplot.ps
  gmt psxy dat/all_${obs}_elevmean.dat -J -R -W1p,black,- -O -K >> plots/${site}_elevplot.ps
  gmt pslegend -Dn0.75/0.03+jBR+w0.2 -J -R -O -K << EOF >> plots/${site}_elevplot.ps
S 0.1i r 0.35,0.05 red - 0.3i $SITE ($obs)
S 0.1i - 0.35 - 1p,black,.- 0.3i All sites ($obs)
EOF
  gmt psxy -J -R -O -T >> plots/${site}_elevplot.ps
  gmt psconvert -A -Tg plots/${site}_elevplot.ps

  #make skyplots
  echo making skyplots for $site
  # original values
  gmt grd2xyz grd/${site}_${obs}_${azincr}-${elincr}.grd -s |awk -v az=$azincr -v el=$elincr '{printf("%f %f %f %f %fd %fd\n",$1,-$2,$3,0,el,az*cos($2*3.14159/180))}' |gmt psxy -SJ -Cmagma_$obs.cpt -R0/360/-90/0 -JS0/-90/5i -Ba90f30g30":.$SITE ${obs}:" -P -K >  plots/${site}_${obs}_skyplot.ps
  gmt psscale  -D5.7i/6.5/10/0.6 -Cmagma_$obs.cpt -E -B25::/:"GPS SNR": -O -K >> plots/${site}_${obs}_skyplot.ps
  gmt psxy -J -R -O -T >> plots/${site}_${obs}_skyplot.ps
  gmt psconvert -A1p -Tg plots/${site}_${obs}_skyplot.ps

  # values with network average by elevation removed
  gmt grdmath grd/${site}_${obs}_${azincr}-${elincr}.grd grd/${obs}_elevmean.grd SUB = grd/${site}_${obs}_${azincr}-${elincr}_diff.grd
  gmt grd2xyz grd/${site}_${obs}_${azincr}-${elincr}_diff.grd -s |awk -v az=$azincr -v el=$elincr '{printf("%f %f %f %f %fd %fd\n",$1,-$2,$3,0,el,az*cos($2*3.14159/180))}' |gmt psxy -SJ -Cpolar10.cpt -R0/360/-90/0 -JS0/-90/5i -Ba90f30g30":.$SITE ${obs} anomaly:" -P -K >  plots/${site}_${obs}_skyplot_diff.ps
  gmt psscale  -D5.7i/6.5/10/0.6 -Cpolar10.cpt -E -B5::/:"delta SNR": -O -K >> plots/${site}_${obs}_skyplot_diff.ps
  gmt psxy -J -R -O -T >> plots/${site}_${obs}_skyplot_diff.ps
  gmt psconvert -A1p -Tg plots/${site}_${obs}_skyplot_diff.ps
done

