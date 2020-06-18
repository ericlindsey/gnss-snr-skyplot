#!/bin/bash

if [[ $# -lt 1 ]] ; then
  echo "Usage: $0 <sites>"
  echo " create timeseries plot from available files in the timeseries/ folder."
  exit 1
fi

gmt gmtset PS_MEDIA A0

source params.config

# create custom colormap
if [[ ! -f colors12_custom.cpt ]]; then
cat << EOF >> colors12_custom.cpt
0	235/235/153
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

#ls timeseries/* |cut -f2 -d/ | awk '{printf("%.4s\n",$1)}' |uniq > siteslist.txt
for site in $@
do 

  # get bounds and create initial frame
  minmax=`gmt gmtinfo -C timeseries/$site-$obs-*.dat`
  minx=`echo $minmax |awk '{print $1-($2-$1)*0.05}'`
  maxx=`echo $minmax |awk '{print $2+($2-$1)*0.05}'`
  miny=30 #`echo $minmax |awk '{print $3-($4-$3)*0.05}'`
  maxy=55 #`echo $minmax |awk '{print $4+($4-$3)*0.05}'`
  bounds="-R$minx/$maxx/$miny/$maxy"
  caps_SITE=`echo $site | tr [:lower:] [:upper:]`
  echo $caps_SITE bounds: $bounds

  ayr=`echo $minx $maxx |awk '{if($2-$1>10) {print 2} else {print 1}}'`
  gmt psbasemap -JX6i/3i $bounds -BWSen+t"Site: $caps_SITE" -Bxa${ayr}f0.08333333+l"Time (Yr)" -Bya5f1+l"$obs SNR (dB)" -P -K > plots/${site}_${obs}_timeseries.ps

  # loop over files and plot each line
  for file in `ls timeseries/$site-$obs-*.dat`
  do
    echo plot $file
    gmt psxy $file -W1p -Ccolors12_custom.cpt -gx0.1 -J -R -O -K >> plots/${site}_${obs}_timeseries.ps
  done

  # create skymap index with time-averaged values on the side
  if [[ ! -f grd/${site}_${obs}_${azincr}-${elincr}.grd ]]; then
    ./grid_last_data.sh $site
  fi
  # note! Negative elevation for some odd reason
  gmt grd2xyz grd/${site}_${obs}_${azincr}-${elincr}.grd -s |awk -v az=$azincr -v el=$elincr '{printf("%f %f %f %f %fd %fd\n",$1,-$2,$3,0,el,az*cos($2*3.14159/180))}' |gmt psxy -SJ -Cmagma_$obs.cpt -R0/360/-90/0 -JS0/-90/3i -Ba90f30g30 -O -K -X7i >>  plots/${site}_${obs}_timeseries.ps

  dx=1
  dy=2
  for file in `ls timeseries/$site-$obs-*.dat`
  do
    f=$(basename $file .dat)
    tr=`echo $f |awk -F- -v az=$ts_azincr -v el=$ts_elincr -v dx=$dx -v dy=$dy '{print $3+az/2-dx-1,-$4-el/2+dy}'`
    tl=`echo $f |awk -F- -v az=$ts_azincr -v el=$ts_elincr -v dx=$dx -v dy=$dy '{print $3-az/2+dx+1,-$4-el/2+dy}'`
    bl=`echo $f |awk -F- -v az=$ts_azincr -v el=$ts_elincr -v dx=$dx -v dy=$dy '{print $3-az/2+dx,-$4+el/2-dy}'`
    br=`echo $f |awk -F- -v az=$ts_azincr -v el=$ts_elincr -v dx=$dx -v dy=$dy '{print $3+az/2-dx,-$4+el/2-dy}'`
    n=`head -n1 $file |awk -FZ '{print $2}'`
    gmt psxy -W2p -Ccolors12_custom.cpt -J -R -O -K << EOF >> plots/${site}_${obs}_timeseries.ps
> -Z$n
$tr
$tl
$bl
$br
$tr
EOF
  done
  gmt psscale  -Dx3.5i/0i+w3i/0.3i+e -Cmagma_$obs.cpt -B10::/:"$obs SNR (dB)": -O -K >> plots/${site}_${obs}_timeseries.ps

  #finalize timeseries plot
  gmt psxy -J -R -O -T >> plots/${site}_${obs}_timeseries.ps
  gmt psconvert -A1p -Tg plots/${site}_${obs}_timeseries.ps
done
