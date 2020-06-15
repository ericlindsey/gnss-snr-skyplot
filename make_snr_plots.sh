#!/bin/bash

# convert all rinex files into SNR files

if [[ $# -lt 1 ]]; then
  echo " Usage: $0 <rinex files>"
  echo " converts SNR data from rinex files to a series of sky-plots."
  exit 1
fi

# azimuth/elevation resolution for plots
azincr=10
elincr=5

# set SNR type:
# 77 = only L2C satellites
# 88 = all data
# 99 = only data between 5 and 30 degree elevation angles
snrtype=88

rm -rf snr
mkdir -p snr
mkdir -p sp3
for file in $@
do
    base=$(basename $file)
    echo working on $base
    doy=${base:4:3}
    yr=${base:9:2}
    stem=$(basename $base .${yr}o)

    # get week and day of week from gamit 'doy' program
    # this requires gamit_globk to be installed (also required for getting the orbits)
    wk=`doy $yr $doy |awk 'NR==2{print $3}'`
    dow=`doy $yr $doy |awk 'NR==2{print $7}' | awk -F, '{print $1}'`
    sp3="sp3/igs${wk}${dow}.sp3"
    echo $sp3
    if [[ ! -f $sp3 ]]; then
        echo "expected orbit file $sp3 not found. Downloading from archive:"
        cd sp3
        ~/gg/com/sh_get_orbits -yr $yr -doy $doy
        cd ..
    fi
    
    ln -s $file .
    echo "./gnssSNR/gnssSNR.e $base $stem.snr$snrtype $sp3 $snrtype"
    ./gnssSNR/gnssSNR.e $base $stem.snr$snrtype $sp3 $snrtype

    mv $stem.snr$snrtype snr/
    rm -f $base

done

# get list of unique sites
ls snr/* |cut -f2 -d/ | awk '{printf("%.4s\n",$1)}' |uniq > siteslist.txt

# convert SNR output to GMT grid files
rm -rf grd
mkdir -p grd
for site in `cat siteslist.txt`
do
  echo $site
  ls snr/$site????.snr$snrtype
  cat snr/$site????.snr$snrtype > snr/$site.snr$snrtype
  echo "awk '{print $3,$2,$7}' snr/$site.snr$snrtype | gmt blockmean -R0/360/0/85 -I$azincr/$elincr |gmt xyz2grd -R0/360/0/85 -I$azincr/$elincr -Ggrd/${site}_S1_$azincr-$elincr.grd"
  awk '{print $3,$2,$7}' snr/$site.snr$snrtype | gmt blockmean -R0/360/0/85 -I$azincr/$elincr |gmt xyz2grd -R0/360/0/85 -I$azincr/$elincr -Ggrd/${site}_S1_$azincr-$elincr.grd
  awk '{print $3,$2,$8}' snr/$site.snr$snrtype | gmt blockmean -R0/360/0/85 -I$azincr/$elincr |gmt xyz2grd -R0/360/0/85 -I$azincr/$elincr -Ggrd/${site}_S2_$azincr-$elincr.grd
done

# average grid files by elevation
rm -rf dat
mkdir -p dat
for site in `cat siteslist.txt`
do
  echo $site
  gmt grd2xyz grd/${site}_S1*.grd -s > dat/${site}_S1.dat
  gmt grd2xyz grd/${site}_S2*.grd -s > dat/${site}_S2.dat
  gmt blockmean -R0/360/0/85 -I800/$elincr dat/${site}_S1.dat |awk '{print $2,$3}' > dat/${site}_S1_elevmean.dat
  gmt blockmean -R0/360/0/85 -I800/$elincr dat/${site}_S2.dat |awk '{print $2,$3}' > dat/${site}_S2_elevmean.dat
done
cat dat/????_S1_elevmean.dat | awk '{print 0,$1,$2}' | gmt blockmean -R0/360/0/85 -I800/$elincr |awk '{print $2,$3}' > dat/all_S1_elevmean.dat
cat dat/????_S2_elevmean.dat | awk '{print 0,$1,$2}' | gmt blockmean -R0/360/0/85 -I800/$elincr |awk '{print $2,$3}' > dat/all_S2_elevmean.dat

#make elevation-angle plots
mkdir -p plots
gmt gmtset MAP_TICK_LENGTH -5p
gmt gmtset MAP_LABEL_OFFSET 15p
gmt gmtset FONT_TITLE 16p
gmt gmtset MAP_ANNOT_OFFSET_PRIMARY 10p
gmt gmtset PS_MEDIA A0

for site in `cat siteslist.txt`
do
  gmt psxy dat/${site}_S1_elevmean.dat -R0/85/0/60 -JX5i/3i -X1i -Y5i -Ba10f5:"Elevation Angle":/a10f5:"GPS signal to noise ratio"::."Site ${site}":WSen -W1p,red -P -K > plots/${site}_elevplot.ps
  gmt psxy dat/${site}_S2_elevmean.dat -J -R -W1p,blue -O -K >> plots/${site}_elevplot.ps
  gmt psxy dat/all_S1_elevmean.dat -J -R -W1p,red,- -O -K >> plots/${site}_elevplot.ps
  gmt psxy dat/all_S2_elevmean.dat -J -R -W1p,blue,- -O -K >> plots/${site}_elevplot.ps
  gmt pslegend -Dn0.75/0.03+jBR+w0.2 -J -R -O -K << EOF >> plots/${site}_elevplot.ps
S 0.1i r 0.35,0.05 red - 0.3i SNR (L1)
S 0.1i r 0.35,0.05 blue - 0.3i SNR (L2)
S 0.1i - 0.35 - 1p,red,.- 0.3i All sites (L1)
S 0.1i - 0.35 - 1p,blue,.- 0.3i All sites (L2)
EOF
  gmt psxy -J -R -O -T >> plots/${site}_elevplot.ps
  gmt psconvert -A -Tg plots/${site}_elevplot.ps

done



#make skyplots
rm -f temp1.dat
rm -f temp2.dat
for x in `seq $azincr $azincr 360`
do
  awk -v x=$x '{print x,$1,$2}' dat/all_S1_elevmean.dat >> temp1.dat
  awk -v x=$x '{print x,$1,$2}' dat/all_S2_elevmean.dat >> temp2.dat
done
gmt xyz2grd temp1.dat -R0/360/0/85 -I$azincr/$elincr -Ggrd/S1_elevmean.grd
gmt xyz2grd temp2.dat -R0/360/0/85 -I$azincr/$elincr -Ggrd/S2_elevmean.grd

for site in `cat siteslist.txt`
do
  echo $site
  gmt grdmath grd/${site}_S1_${azincr}-${elincr}.grd grd/S1_elevmean.grd SUB = grd/${site}_S1_${azincr}-${elincr}_diff.grd
  gmt grdmath grd/${site}_S2_${azincr}-${elincr}.grd grd/S2_elevmean.grd SUB = grd/${site}_S2_${azincr}-${elincr}_diff.grd
done

gmt makecpt -Cmagma -T0/50/1 -D -Z >magma50.cpt
gmt makecpt -Cpolar -T-10/10/1 -D -Z >polar10.cpt

for site in `cat siteslist.txt`
do
  echo $site
  gmt grd2xyz grd/${site}_S1_${azincr}-${elincr}_diff.grd -s |awk -v az=$azincr -v el=$elincr '{printf("%f %f %f %f %fd %fd\n",$1,-$2,$3,0,el,az*cos($2*3.14159/180))}' |gmt psxy -SJ -Cpolar10.cpt -R0/360/-90/0 -JS0/-90/5i -Ba90f30g30":.$site S1:" -P -K >  plots/${site}_skyplot_diff.ps
  gmt psscale  -D5.7i/6.5/10/0.6 -Cpolar10.cpt -E -B5::/:"delta SNR": -O -K >> plots/${site}_skyplot_diff.ps
  gmt grd2xyz grd/${site}_S2_${azincr}-${elincr}_diff.grd -s |awk -v az=$azincr -v el=$elincr '{printf("%f %f %f %f %fd %fd\n",$1,-$2,$3,0,el,az*cos($2*3.14159/180))}' |gmt psxy -X7i -SJ -Cpolar10.cpt -R0/360/-90/0 -JS0/-90/5i -Ba90f30g30":.$site S2:" -P -O -K >> plots/${site}_skyplot_diff.ps
  gmt psscale  -D5.7i/6.5/10/0.6 -Cpolar10.cpt -E -B5::/:"delta SNR": -O -K >> plots/${site}_skyplot_diff.ps
  
  gmt psxy -J -R -O -T >> plots/${site}_skyplot_diff.ps
  gmt psconvert -A1p -Tg plots/${site}_skyplot_diff.ps

  gmt grd2xyz grd/${site}_S1_${azincr}-${elincr}.grd -s |awk -v az=$azincr -v el=$elincr '{printf("%f %f %f %f %fd %fd\n",$1,-$2,$3,0,el,az*cos($2*3.14159/180))}' |gmt psxy -SJ -Cmagma50.cpt -R0/360/-90/0 -JS0/-90/5i -Ba90f30g30":.$site S1:" -P -K >  plots/${site}_skyplot.ps
  gmt psscale  -D5.7i/6.5/10/0.6 -Cmagma50.cpt -E -B25::/:"GPS SNR": -O -K >> plots/${site}_skyplot.ps
  gmt grd2xyz grd/${site}_S2_${azincr}-${elincr}.grd -s |awk -v az=$azincr -v el=$elincr '{printf("%f %f %f %f %fd %fd\n",$1,-$2,$3,0,el,az*cos($2*3.14159/180))}' |gmt psxy -X7i -SJ -Cmagma50.cpt -R0/360/-90/0 -JS0/-90/5i -Ba90f30g30":.$site S2:" -P -O -K >> plots/${site}_skyplot.ps
  gmt psscale  -D5.7i/6.5/10/0.6 -Cmagma50.cpt -E -B25::/:"GPS SNR": -O -K >> plots/${site}_skyplot.ps
  
  gmt psxy -J -R -O -T >> plots/${site}_skyplot.ps
  gmt psconvert -A1p -Tg plots/${site}_skyplot.ps
done




rm -f plots/*.ps temp1.dat temp2.dat

