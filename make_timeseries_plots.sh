#!/bin/bash

echo " create timeseries plot from available files in the timeseries/ folder."

gmt gmtset PS_MEDIA A0

# azimuth/elevation resolution for plots
azincr=10
elincr=5
# azimuth/elevation resolution for timeseries
ts_azincr=60
ts_elincr=45
#choose observable: S1 or S2
obs=S1

# create custom colormap
if [[ ! -f colors12_custom.cpt ]]; then
cat << EOF >> colors12_custom.cpt
0	255/255/153
1	202/178/214
2	253/191/111
3	251/154/153
4	178/223/138
5	166/206/227
6	177/89/40
7	106/61/154
8	darkorange1
9	227/26/28
10	51/160/44
11	31/120/180
B	black
F	white
N	127.5
EOF
fi

ls timeseries/* |cut -f2 -d/ | awk '{printf("%.4s\n",$1)}' |uniq > siteslist.txt

for site in `cat siteslist.txt`
do 
  # get bounds and create initial frame
  minmax=`gmt gmtinfo -C timeseries/$site-$obs-*.dat`
  minx=`echo $minmax |awk '{print $1-($2-$1)*0.05}'`
  maxx=`echo $minmax |awk '{print $2+($2-$1)*0.05}'`
  miny=`echo $minmax |awk '{print $3-($4-$3)*0.05}'`
  maxy=`echo $minmax |awk '{print $4+($4-$3)*0.05}'`
  bounds="-R$minx/$maxx/$miny/$maxy"
  echo $bounds
  caps_SITE=`echo $site | tr [:lower:] [:upper:]`

  gmt psbasemap -JX6i/3i $bounds -BWSen+t"Site: $caps_SITE" -Bxa1f0.08333333+l"Time (Yr)" -Bya5f1+l"$obs SNR (dB)" -P -K > plots/${site}_${obs}_timeseries.ps

  # loop over files and plot each line
  for file in `ls timeseries/$site-$obs-*.dat`
  do
    gmt psxy $file -W1p -Ccolors12_custom.cpt -J -R -O -K >> plots/${site}_${obs}_timeseries.ps
  done

  # get point coordinates for index map
  rm -f dat/ptsfile.dat
  for file in `ls timeseries/$site-$obs-*.dat`
  do
    filebase=$(basename $file .dat)
    # note! Negative elevation for some odd reason
    azpt=`echo $filebase |awk -F- '{print $3}'`
    elpt=`echo $filebase |awk -F- '{print -$4}'`
    n=`head -n1 $file |awk -FZ '{print $2}'`
    echo $azpt $elpt $n >> dat/ptsfile.dat
  done
  # create skymap index with time-averaged values on the side
  gmt grd2xyz grd/${site}_${obs}_${azincr}-${elincr}.grd -s |awk -v az=$azincr -v el=$elincr '{printf("%f %f %f %f %fd %fd\n",$1,-$2,$3,0,el,az*cos($2*3.14159/180))}' |gmt psxy -SJ -Cmagma_$obs.cpt -R0/360/-90/0 -JS0/-90/3i -Ba90f30g30 -O -K -X7i >>  plots/${site}_${obs}_timeseries.ps
  gmt psxy dat/ptsfile.dat -Sp0.4c -Ccolors12_custom.cpt -J -R -O -K >> plots/${site}_${obs}_timeseries.ps
  gmt psxy dat/ptsfile.dat -Sc0.4c -W0.5p,black -J -R -O -K >> plots/${site}_${obs}_timeseries.ps
  gmt psscale  -Dx3.5i/0i+w3i/0.3i+e -Cmagma_$obs.cpt -B10::/:"$obs SNR (dB)": -O -K >> plots/${site}_${obs}_timeseries.ps

  #finalize timeseries plot
  gmt psxy -J -R -O -T >> plots/${site}_${obs}_timeseries.ps
  gmt psconvert -A1p -Tg plots/${site}_${obs}_timeseries.ps
done

#rm -f plots/*.ps
#rm -f temp.dat

