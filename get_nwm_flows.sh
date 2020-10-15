#!/bin/bash
# this script:
# 1.downloads and processes analyses, 18 hr and ensemble 120 hour forecasts a from the national water model 
# 2.subsets the ~50 stream segments relevant for champlain FVCOM model (as defined by textfile `ids.txt`)
# 3.concatenates the data for the entire day/forecast-horizon into a single file for each day/initialization
# developed by James Kessler (james.kessler@noaa.gov) circa October 2016


YYYYMMDD=$(date -d "-70 minutes" +%Y%m%d) # define date by 70 minutes ago to make sure the 23Z analysis is grabbed
#YYYYMMDD=20200323
base_url='https://nomads.ncep.noaa.gov/pub/data/nccf/com/nwm/prod/nwm'
cd /mnt/projects/ipemf/kessler/nwm/

# define desired feature_ids and variables to process
#                              add -d fid to newline;rm trail ws; add decimal | remove newlines
dim_arg=$(sed -r 's/^/-d feature_id,/g; s/\s+$//g; s/$/.0/g' ids.txt | tr '\n' ' ')
var_arg='-v streamflow,velocity,feature_id,time'
last=$(cat last_run.date)

echo ==============  `date '+%D %T'` =====================
1>&2 echo ==============  `date '+%D %T'` =====================

# =====================================================================================================
# ============================   get analysis =========================================================
# =====================================================================================================
#
# check to see if it's a new day
if [[ $YYYYMMDD -gt $last ]]; then
	echo its a new dawn, its a new day...

	# check to see if previous day was completed
	tsteps=$(/usr/local/bin/ncdump -h analysis/${last}.nc | grep -m1 time | grep -Eo '[0-9]+')
	echo $tsteps
	if [[ $tsteps -eq 24 ]]; then # good; delete
		rm -rf today
	else # somethign went wrong; save previous day; alert me
		echo "fatal: $last did not complete" | mailx -s NWM_acquisition james.kessler+logs@noaa.gov
		mv today unproc_$last
	fi
fi
	
[[ -d today ]] || mkdir today

echo checking for new analysis files for $YYYYMMDD...
wget -nc -q -P today ${base_url}.${YYYYMMDD}/analysis_assim/nwm.t{00..23}z.analysis_assim.channel_rt.tm00.conus.nc &
wait
for fin in $(find today -type f -iname '*.nc' -cmin -5); do
	echo "Found: $fin"
	/usr/local/bin/ncks -O $dim_arg $var_arg $fin $fin 
	/usr/local/bin/ncpdq -O -U $fin $fin

#	# check file date and abort if it's not correct (this shouldn't be necesary anymore)
#	fin_date=$(echo $(/usr/local/bin/ncks --trd -HCs '%i\n' -d time,0 -v time $fin)*60 | bc | xargs -i date -d@{} +%Y%m%d)
#	[[ $fin_date -eq $YYYYMMDD ]] || echo "fatal: date is wrong!" | mailx -s NWM_acquisition james.kessler+logs@noaa.gov

done

# concatenate files (handle single 0Z file seperately)
nfiles=$(find today -type f -name '*.nc' | wc -l)

if [[ $nfiles -gt 1 ]]; then # default behavior (simple)
	/home/kessler/.local/bin/cdo --no_warnings copy today/*.nc analysis/${YYYYMMDD}.nc  
else # work around for single file, CDO fails to manipulate time dim correctly:  streamflow(fid) insteadf of streamflow(fid, time) 
	/home/kessler/.local/bin/cdo --no_warnings copy today/*.nc today/*.nc analysis/${YYYYMMDD}.nc  # duplicate timestep so time dim is correct
	/usr/local/bin/ncrcat -O -d time,0 analysis/${YYYYMMDD}.nc analysis/${YYYYMMDD}.nc			       # remove duplicated timestep
fi

chmod +r analysis/${YYYYMMDD}.nc		
echo $YYYYMMDD > last_run.date


# =====================================================================================================
# ============================  get 18 hr forecast (init hours 0, 12) ==================================
# =====================================================================================================

# remove any lingering downloaded Forecast files
rm -rf download
echo -n checking for new 18hr fc files for $YYYYMMDD...
for HH in {00,12}; do 
	#check to see if file was already downloaded & processed; if so skip to next iter
	[[ -f short/${YYYYMMDD}${HH}.nc ]] && continue
	# check to see if newest file is available to dl; if not, skip to next iter (could probably just exit loop instead)
	wget -q --spider ${base_url}.${YYYYMMDD}/short_range/nwm.t${HH}z.short_range.channel_rt.f001.conus.nc; [[ $? -ne 0 ]] && continue 
	

	mkdir download # make temp dir
	echo "Found!"
	echo -e "\tprocessing for init hr $HH"
	wget -q -P download ${base_url}.${YYYYMMDD}/short_range/nwm.t${HH}z.short_range.channel_rt.f0{01..18}.conus.nc &
	wait

	ls download/*.nc | while read fin; do
		/usr/local/bin/ncks -O $dim_arg $var_arg $fin $fin 
		/usr/local/bin/ncpdq -O -U $fin $fin 
	done
	# concatenate 18 hour forecast and remove individual files
	/home/kessler/.local/bin/cdo --no_warnings copy download/*.nc short/${YYYYMMDD}${HH}.nc 
	chmod +r short/${YYYYMMDD}${HH}.nc		
	rm -rf download
done



## =====================================================================================================
## ====================  get medium range forecast (init hours 0, 12) ==================================
## =====================================================================================================

# remove any lingering downloaded Forecast files
rm -rf download_m?

echo -e '\n'checking for new medium range fc files for $YYYYMMDD...
for HH in {00,12}; do 
	for mem in {1..7}; do
		# do checks
		[[ -f medium/m${mem}/${YYYYMMDD}${HH}.nc ]] && continue # did i already process file?
		wget -q --spider ${base_url}.${YYYYMMDD}/medium_range_mem${mem}/nwm.t${HH}z.medium_range.channel_rt_${mem}.f003.conus.nc; [[ $? -ne 0 ]] && continue # new file on nomads?


		echo -e "\tFound ens mem $mem; processing..."

		mkdir download_m${mem} # make temp dir
		wget -q -P download_m${mem} ${base_url}.${YYYYMMDD}/medium_range_mem${mem}/nwm.t${HH}z.medium_range.channel_rt_${mem}.f{003..120..3}.conus.nc &
		wait

		# unpack
		ls download_m${mem}/*.nc | while read fin; do
			/usr/local/bin/ncpdq -O -U $fin $fin
		done

		# clip
		ls download_m${mem}/*.nc | while read fin; do
			/usr/local/bin/ncks -O $dim_arg $var_arg $fin $fin &
			# don't be a resource hog (limit parallel ncks)
			while [[ $(pgrep -u kessler ncks | wc -l) -gt 8 ]]; do sleep .25; done 		 
		done

		# a simple wait command instead of below line SHOULD work but doesn't (maybe i don't understand a child process)
		while [[ $(pgrep -u kessler ncks | wc -l) -gt 0 ]]; do sleep .25; done 		 

		# concatenate
		/home/kessler/.local/bin/cdo --no_warnings copy download_m${mem}/*.nc medium/m${mem}/${YYYYMMDD}${HH}.nc 
		chmod +r medium/m${mem}/${YYYYMMDD}${HH}.nc 
		rm -rf download_m${mem}
	done
done



echo finished at:  `date '+%D %T'` 
1>&2 echo finished at:  `date '+%D %T'` 

