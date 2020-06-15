gnss-snr-skyplot
-------

System requirements: gmt, GAMIT/GLOBK

This script makes use of Kristine Larson's SNR extractor (https://github.com/kristinemlarson/gnssSNR) to create some simple sky plots of the SNR at each site. Currently, the plots show SNR for the L1 and L2 frequencies (GPS observables S1 and S2), both with and without an azimuthal average subtracted. Timeseries plots are coming soon.

Use of the script: first, go to the gnssSNR subdirectory and type 'make'. You must have gfortran for this to work.

Now, go up one directory, and run ./make_snr_plots.sh <rinex_files>. The rinex files must be version 2.11. The script will determine the day from the filename format, auto-download igs orbits using the GAMIT command sh_get_orbits, and then run gnssSNR.e to extract the SNR values. After this, some GMT plotting and averaging commands will be used to make the figures.

If you want a better estimate of the noise at a particular site, use more data - the script will combine all available data to estimate the SNR at a particular azimuth/elevation.

The binning size for azimuth and elevation are hard-coded at the top of the script. Feel free to change them as you like.

