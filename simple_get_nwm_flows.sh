#!/bin/bash
# this script:
# 1.downloads and processes channel route output from NWM analysis
# 2.subsets the N stream segments as defined by textfile `ids.txt`
# 3.concatenates the data for the entire day into a single file for each day/initialization
# developed by James Kessler (james.kessler@noaa.gov) circa October 2016


# ======== user controls ========================
YYYYMMDD=20201014 # must be today or yesterday based on availability at nomads
base_url='https://nomads.ncep.noaa.gov/pub/data/nccf/com/nwm/prod/nwm'
# which variables do you want from chrout netCDFS
var_arg='-v streamflow,velocity,feature_id,time'   # form : '-v variable1,variable2,' (note lack of spaces)
out_dir='output'


# ====== 0. setup ================================================
[[ -e $out_dir ]] || mkdir $out_dir
# use sed to build a string that ncks can use to subset the stream segments by feature id =======
# sed steps explanation: add -d fid to newline;rm trail whtspc; add decimal | remove newlines
dim_arg=$(sed -r 's/^/-d feature_id,/g; s/\s+$//g; s/$/.0/g' ids.txt | tr '\n' ' ') 

# ====== 1. download and trim files ===============================
echo checking for analysis files for $YYYYMMDD...
wget -q -P tmp ${base_url}.${YYYYMMDD}/analysis_assim/nwm.t{00..23}z.analysis_assim.channel_rt.tm00.conus.nc &
wait
for fin in $(find tmp -type f -iname '*.nc' -cmin -5); do
	echo "Found: $fin"
	ncks -O $dim_arg $var_arg $fin $fin 
	ncpdq -O -U $fin $fin
done

# ====== 3. concatenate files, cleanup ========================
cdo copy tmp/*.nc $out_dir/${YYYYMMDD}.nc  
rm -rf tmp


