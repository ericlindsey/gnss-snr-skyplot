#!/bin/bash

#script to test that you have installed everything correctly

# test rinex file has a non-standard name, link it as a standard name temporarily
ln -s gnssSNR/at013620.18o.test at013620.18o
# run the gnssSNR test data
./grid_snr_data rinex/at013620.18o
# remove link
rm -f at013620.18o
# make plots
./make_skymaps.sh
./make_timeseries_plots.sh

