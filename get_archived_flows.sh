#!/bin/bash
# developed by James Kessler (james.kessler@noaa.gov) circa October 2016

base_url='gs://national-water-model'
cd /mnt/projects/ipemf/kessler/nwm/from_archives/

# define desired feature_ids and variables to process
#                              add -d fid to newline;rm trail ws; add decimal | remove newlines
dim_arg=$(sed -r 's/^/-d feature_id,/g; s/\s+$//g; s/$/.0/g' ../ids.txt| tr '\n' ' ')
var_arg='-v streamflow,velocity,feature_id,time'

lk_id='-d feature_id,15447630.0'
lk_vars='-v feature_id,inflow,outflow,time'
# =====================================================================================================
# ============================   get analysis =========================================================
# =====================================================================================================

t0=20190103        # first record to grab
tf=20200630
#tf=$(date +%Y%m%d) # last record to grab (default: today)

anal=1  # get analysis?
shrt=0  # get short fc
med=0   # get med fc



if [ $anal == 1 ]; then
echo downloading/processing analysis files... 
YYYYMMDD=$t0
rm -rf temp 2> /dev/null
while [[ $YYYYMMDD -le $tf ]]; do
	echo $YYYYMMDD

	#1. download & process streamflows (channel_rt files)
	mkdir temp
	gsutil -qm cp ${base_url}/nwm.${YYYYMMDD}/analysis_assim/nwm.t{00..23}z.analysis_assim.channel_rt.tm00.conus.nc temp
	/home/kessler/.local/bin/cdo --no_warnings copy temp/*channel_rt*.nc temp/${YYYYMMDD}.nc  # concatenate
	/usr/bin/ncks -O $dim_arg $var_arg temp/${YYYYMMDD}.nc  temp/${YYYYMMDD}.nc         # clip
	mv temp/${YYYYMMDD}.nc analysis/${YYYYMMDD}.nc  
	rm -rf temp

	#2.  download and process inflows/outflows (reservoir file) 
	mkdir temp
	gsutil -qm cp ${base_url}/nwm.${YYYYMMDD}/analysis_assim/nwm.t{00..23}z.analysis_assim.reservoir.tm00.conus.nc temp
	/home/kessler/.local/bin/cdo --no_warnings copy temp/*.nc temp/${YYYYMMDD}.nc      # concatenate
	/usr/bin/ncks -O $lk_id $lk_vars temp/${YYYYMMDD}.nc  temp/${YYYYMMDD}.nc    # clip
	ncrename -d feature_id,lk_id -v feature_id,lk_id temp/${YYYYMMDD}.nc               # rename fid to avoid dim-mismatch

	#3. combine output from 1 and 2; cleanup
	ncks -A temp/${YYYYMMDD}.nc analysis/${YYYYMMDD}.nc		                   # append in/outflows
	/usr/bin/ncpdq -O -U analysis/${YYYYMMDD}.nc  analysis/${YYYYMMDD}.nc        # unpack
	chmod +r analysis/${YYYYMMDD}.nc		
	rm -rf temp

	YYYYMMDD=$(date -d "$YYYYMMDD + 1 day" +%Y%m%d)
done
fi


# =====================================================================================================
# ============================  get 18 hr forecast (init hours 0, 12) ==================================
# =====================================================================================================

if [ $shrt == 1 ]; then
echo downloading 18 hour FC\'s...
YYYYMMDD=$t0
rm -rf temp 2> /dev/null
while [[ $YYYYMMDD -le $tf ]]; do
	echo $YYYYMMDD
	for HH in {00,12}; do 
		#download
		mkdir temp
		gsutil -qm cp ${base_url}/nwm.${YYYYMMDD}/short_range/nwm.t${HH}z.short_range.channel_rt.f{001..018}.nc temp

		# process (concatenate; clip; unpack)
		/home/kessler/.local/bin/cdo --no_warnings copy temp/*.nc temp/${YYYYMMDD}${HH}.nc  # concatenate
		/usr/bin/ncks -O $dim_arg $var_arg temp/${YYYYMMDD}${HH}.nc  temp/${YYYYMMDD}${HH}.nc  
		/usr/bin/ncpdq -O -U temp/${YYYYMMDD}${HH}.nc  temp/${YYYYMMDD}${HH}.nc  

		# save final and cleanup
		mv temp/${YYYYMMDD}${HH}.nc analysis/${YYYYMMDD}${HH}.nc  
		chmod +r short/${YYYYMMDD}${HH}.nc		
		rm -rf temp
	done
	YYYYMMDD=$(date -d "$YYYYMMDD + 1 day" +%Y%m%d)
done
fi

## =====================================================================================================
## ====================  get medium range forecast (init hours 0, 12) ==================================
## =====================================================================================================
if [ $med == 1 ]; then
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
			/usr/bin/ncpdq -O -U $fin $fin
		done

		# clip
		ls download_m${mem}/*.nc | while read fin; do
			/usr/bin/ncks -O $dim_arg $var_arg $fin $fin &
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
fi



echo finished at:  `date '+%D %T'` 
1>&2 echo finished at:  `date '+%D %T'` 

