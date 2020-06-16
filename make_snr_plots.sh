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

mkdir -p snr
mkdir -p sp3
# loop over all input rinex files.
for file in $@
do
  base=$(basename $file)
  echo working on $base
  site=${base:0:4}
  doy=${base:4:3}
  yr=${base:9:2}
  stem=$(basename $base .${yr}o)

  # Check if the corresponding SNR file exists already, if not, create it.
  if [[ ! -f snr/$stem.snr$snrtype ]]; then

    # get week and day of week from gamit 'doy' program
    # this requires gamit_globk to be installed (also required for getting the orbits)
    wk=`doy $yr $doy |awk 'NR==2{print $3}'`
    dow=`doy $yr $doy |awk 'NR==2{print $7}' | awk -F, '{print $1}'`
    sp3="sp3/igs${wk}${dow}.sp3"
    echo $sp3
    if [[ ! -f $sp3 ]]; then
        echo "expected orbit file $sp3 not found. Downloading from archive:"
        cd sp3
        ~/gg/com/sh_get_orbits -yr $yr -doy $doy -makeg no
        #~/gg/com/sh_get_orbits -orbit igsf -nofit -yr $yr -doy $doy
        cd ..
    fi
    
    ln -s $file .
    echo "./gnssSNR/gnssSNR.e $base $stem.snr$snrtype $sp3 $snrtype"
    ./gnssSNR/gnssSNR.e $base $stem.snr$snrtype $sp3 $snrtype

    mv $stem.snr$snrtype snr/

  fi
  # grid each day, for timeseries
  if [[ $obs == "S1" ]]; then
    awk '{print $3,$2,$7}' snr/$stem.snr$snrtype > temp.dat 
  else
    awk '{print $3,$2,$8}' snr/$stem.snr$snrtype > temp.dat 
  fi
  gmt blockmean temp.dat -R0/360/0/85 -I$ts_azincr/$ts_elincr |gmt xyz2grd -R0/360/0/85 -I$ts_azincr/$ts_elincr -r -Gts_grd/${site}_${yr}_${doy}_S1_$ts_azincr-$ts_elincr.grd
done

gmt makecpt -Cmagma -T20/50/1 -D -Z >magma_S1.cpt
gmt makecpt -Cmagma -T0/50/1 -D -Z >magma_S2.cpt
gmt makecpt -Cpolar -T-10/10/1 -D -Z >polar10.cpt

# get list of unique 4-character site names
ls snr/* |cut -f2 -d/ | awk '{printf("%.4s\n",$1)}' |uniq > siteslist.txt

# # convert SNR output to GMT grid files
# mkdir -p grd
# mkdir -p ts_grd
# for site in `cat siteslist.txt`
# do
#   echo gridding SNR values: $site
#   #grid all data for each day for averaged sky plots
#   cat snr/$site????.snr$snrtype > snr/$site.snr$snrtype
#   if [[ $obs == "S1" ]]; then
#     awk '{print $3,$2,$7}' snr/$site.snr$snrtype > temp.dat 
#   else 
#     awk '{print $3,$2,$8}' snr/$site.snr$snrtype > temp.dat 
#   fi
#   gmt blockmean temp.dat -R0/360/0/85 -I$azincr/$elincr |gmt xyz2grd -R0/360/0/85 -I$azincr/$elincr -Ggrd/${site}_S1_$azincr-$elincr.grd
# done
# 
#  # average combined grid files by elevation
#  rm -rf dat
#  mkdir -p dat
#  for site in `cat siteslist.txt`
#  do
#    echo averaging by elevation: $site
#    gmt grd2xyz grd/${site}_${obs}*.grd -s > dat/${site}_${obs}.dat
#    gmt blockmean -R0/360/0/85 -I800/$elincr dat/${site}_${obs}.dat |awk '{print $2,$3}' > dat/${site}_${obs}_elevmean.dat
#  done
#  cat dat/????_${obs}_elevmean.dat | awk '{print 0,$1,$2}' | gmt blockmean -R0/360/0/85 -I800/$elincr |awk '{print $2,$3}' > dat/all_${obs}_elevmean.dat
#  
#  #make elevation-angle plots
#  mkdir -p plots
#  gmt gmtset MAP_TICK_LENGTH -5p
#  gmt gmtset MAP_LABEL_OFFSET 15p
#  gmt gmtset FONT_TITLE 16p
#  gmt gmtset MAP_ANNOT_OFFSET_PRIMARY 10p
#  gmt gmtset PS_MEDIA A0
#  
#  for site in `cat siteslist.txt`
#  do
#    gmt psxy dat/${site}_${obs}_elevmean.dat -R0/85/0/60 -JX5i/3i -X1i -Y5i -Ba10f5:"Elevation Angle":/a10f5:"GPS signal to noise ratio"::."Site ${site}":WSen -W1p,red -P -K > plots/${site}_elevplot.ps
#    gmt psxy dat/all_${obs}_elevmean.dat -J -R -W1p,black,- -O -K >> plots/${site}_elevplot.ps
#    gmt pslegend -Dn0.75/0.03+jBR+w0.2 -J -R -O -K << EOF >> plots/${site}_elevplot.ps
#  S 0.1i r 0.35,0.05 red - 0.3i SNR ($obs)
#  S 0.1i - 0.35 - 1p,black,.- 0.3i All sites ($obs)
#  EOF
#    gmt psxy -J -R -O -T >> plots/${site}_elevplot.ps
#    gmt psconvert -A -Tg plots/${site}_elevplot.ps
#  
#  done
#  
#  #make skyplots
#  rm -f temp.dat
#  for x in `seq $azincr $azincr 360`
#  do
#    awk -v x=$x '{print x,$1,$2}' dat/all_${obs}_elevmean.dat >> temp.dat
#  done
#  gmt xyz2grd temp.dat -R0/360/0/85 -I$azincr/$elincr -Ggrd/${obs}_elevmean.grd
#  
#  for site in `cat siteslist.txt`
#  do
#    echo $site
#    gmt grdmath grd/${site}_${obs}_${azincr}-${elincr}.grd grd/${obs}_elevmean.grd SUB = grd/${site}_${obs}_${azincr}-${elincr}_diff.grd
#  done
#  
#  
#  for site in `cat siteslist.txt`
#  do
#    echo making skyplots for $site
#    gmt grd2xyz grd/${site}_${obs}_${azincr}-${elincr}_diff.grd -s |awk -v az=$azincr -v el=$elincr '{printf("%f %f %f %f %fd %fd\n",$1,-$2,$3,0,el,az*cos($2*3.14159/180))}' |gmt psxy -SJ -Cpolar10.cpt -R0/360/-90/0 -JS0/-90/5i -Ba90f30g30":.$site ${obs}:" -P -K >  plots/${site}_skyplot_diff.ps
#    gmt psscale  -D5.7i/6.5/10/0.6 -Cpolar10.cpt -E -B5::/:"delta SNR": -O -K >> plots/${site}_skyplot_diff.ps
#    
#    gmt psxy -J -R -O -T >> plots/${site}_skyplot_diff.ps
#    gmt psconvert -A1p -Tg plots/${site}_skyplot_diff.ps
#  
#    gmt grd2xyz grd/${site}_${obs}_${azincr}-${elincr}.grd -s |awk -v az=$azincr -v el=$elincr '{printf("%f %f %f %f %fd %fd\n",$1,-$2,$3,0,el,az*cos($2*3.14159/180))}' |gmt psxy -SJ -Cmagma_$obs.cpt -R0/360/-90/0 -JS0/-90/5i -Ba90f30g30":.$site ${obs}:" -P -K >  plots/${site}_skyplot.ps
#    gmt psscale  -D5.7i/6.5/10/0.6 -Cmagma_$obs.cpt -E -B25::/:"GPS SNR": -O -K >> plots/${site}_skyplot.ps
#    
#    gmt psxy -J -R -O -T >> plots/${site}_skyplot.ps
#    gmt psconvert -A1p -Tg plots/${site}_skyplot.ps
#  done

# make timeseries and plots
# start from a clean folder
rm -rf timeseries
mkdir -p timeseries
for site in `cat siteslist.txt`
do 
  echo making timeseries plots for $site
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

  # now make the plot - get bounds and create initial frame
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
  gmt psxy dat/ptsfile.dat -Sc0.4c -W0.5p,black -G+z -Ccolors12_custom.cpt -J -R -O -K >> plots/${site}_${obs}_timeseries.ps
  gmt psscale  -Dx3.5i/0i+w3i/0.3i -Cmagma_$obs.cpt -E -B10::/:"$obs SNR (dB)": -O -K >> plots/${site}_${obs}_timeseries.ps

  #finalize timeseries plot
  gmt psxy -J -R -O -T >> plots/${site}_${obs}_timeseries.ps
  gmt psconvert -A1p -Tg plots/${site}_${obs}_timeseries.ps
done

#rm -f plots/*.ps
rm -f temp.dat

