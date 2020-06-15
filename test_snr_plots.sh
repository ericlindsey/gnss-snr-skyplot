#!/bin/bash

#script to test that you have installed everything correctly

#make directories
mkdir -p nav rinex snr grd dat plots

# run the gnssSNR test data
cp gnssSNR/at013620.18o.test rinex/at013620.18o
./make_snr_plots.sh rinex/at013620.18o


