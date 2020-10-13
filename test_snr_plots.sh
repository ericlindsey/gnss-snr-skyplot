#!/bin/bash

#script to test that you have installed everything correctly

# the standard test rinex file has a non-standard name, so first we link it as a standard name temporarily
mkdir -p rinex
ln -s ../gnssSNR/at013620.18o.test rinex/at013620.18o

# extract the SNR data using the gnssSNR library
./extract_snr_data.sh rinex/at013620.18o

# remove link
rm -f rinex/at013620.18o

# make plots
./make_skymaps.sh at01

# timeseries - note, this doesn't work with only one file...
# ./grid_for_timeseries.sh snr/at01*
# ./make_timeseries_plots.sh at01

