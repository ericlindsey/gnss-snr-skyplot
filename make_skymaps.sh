#!/bin/bash

# average combined grid files by elevation
rm -rf dat
mkdir -p dat
for site in `cat siteslist.txt`
do
  echo averaging by elevation: $site
  gmt grd2xyz grd/${site}_${obs}*.grd -s > dat/${site}_${obs}.dat
  gmt blockmean -R0/360/0/85 -I800/$elincr dat/${site}_${obs}.dat |awk '{print $2,$3}' > dat/${site}_${obs}_elevmean.dat
done
cat dat/????_${obs}_elevmean.dat | awk '{print 0,$1,$2}' | gmt blockmean -R0/360/0/85 -I800/$elincr |awk '{print $2,$3}' > dat/all_${obs}_elevmean.dat

#make elevation-angle plots
gmt gmtset MAP_TICK_LENGTH -5p
gmt gmtset MAP_LABEL_OFFSET 15p
gmt gmtset FONT_TITLE 16p
gmt gmtset MAP_ANNOT_OFFSET_PRIMARY 10p
gmt gmtset PS_MEDIA A0

for site in `cat siteslist.txt`
do
  gmt psxy dat/${site}_${obs}_elevmean.dat -R0/85/0/60 -JX5i/3i -X1i -Y5i -Ba10f5:"Elevation Angle":/a10f5:"GPS signal to noise ratio"::."Site ${site}":WSen -W1p,red -P -K > plots/${site}_elevplot.ps
  gmt psxy dat/all_${obs}_elevmean.dat -J -R -W1p,black,- -O -K >> plots/${site}_elevplot.ps
  gmt pslegend -Dn0.75/0.03+jBR+w0.2 -J -R -O -K << EOF >> plots/${site}_elevplot.ps
S 0.1i r 0.35,0.05 red - 0.3i SNR ($obs)
S 0.1i - 0.35 - 1p,black,.- 0.3i All sites ($obs)
EOF
  gmt psxy -J -R -O -T >> plots/${site}_elevplot.ps
  gmt psconvert -A -Tg plots/${site}_elevplot.ps

done

#make skyplots
rm -f temp.dat
for x in `seq $azincr $azincr 360`
do
  awk -v x=$x '{print x,$1,$2}' dat/all_${obs}_elevmean.dat >> temp.dat
done
gmt xyz2grd temp.dat -R0/360/0/85 -I$azincr/$elincr -Ggrd/${obs}_elevmean.grd

for site in `cat siteslist.txt`
do
  echo $site
  gmt grdmath grd/${site}_${obs}_${azincr}-${elincr}.grd grd/${obs}_elevmean.grd SUB = grd/${site}_${obs}_${azincr}-${elincr}_diff.grd
done


for site in `cat siteslist.txt`
do
  echo making skyplots for $site
  gmt grd2xyz grd/${site}_${obs}_${azincr}-${elincr}_diff.grd -s |awk -v az=$azincr -v el=$elincr '{printf("%f %f %f %f %fd %fd\n",$1,-$2,$3,0,el,az*cos($2*3.14159/180))}' |gmt psxy -SJ -Cpolar10.cpt -R0/360/-90/0 -JS0/-90/5i -Ba90f30g30":.$site ${obs}:" -P -K >  plots/${site}_${obs}_skyplot_diff.ps
  gmt psscale  -D5.7i/6.5/10/0.6 -Cpolar10.cpt -E -B5::/:"delta SNR": -O -K >> plots/${site}_${obs}_skyplot_diff.ps
  
  gmt psxy -J -R -O -T >> plots/${site}_${obs}_skyplot_diff.ps
  gmt psconvert -A1p -Tg plots/${site}_${obs}_skyplot_diff.ps

  gmt grd2xyz grd/${site}_${obs}_${azincr}-${elincr}.grd -s |awk -v az=$azincr -v el=$elincr '{printf("%f %f %f %f %fd %fd\n",$1,-$2,$3,0,el,az*cos($2*3.14159/180))}' |gmt psxy -SJ -Cmagma_$obs.cpt -R0/360/-90/0 -JS0/-90/5i -Ba90f30g30":.$site ${obs}:" -P -K >  plots/${site}_${obs}_skyplot.ps
  gmt psscale  -D5.7i/6.5/10/0.6 -Cmagma_$obs.cpt -E -B25::/:"GPS SNR": -O -K >> plots/${site}_${obs}_skyplot.ps
  
  gmt psxy -J -R -O -T >> plots/${site}_${obs}_skyplot.ps
  gmt psconvert -A1p -Tg plots/${site}_${obs}_skyplot.ps
done
