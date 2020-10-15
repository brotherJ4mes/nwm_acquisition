# nwm_acquisition code

**purpose:**      Downloading and processing NWM output from either NCEP or google archives.  

Currently, this code is set up to download streamflow and velocity data from NWM chrtout (channel route out) netCDFs, tho it could be adapted and utilized for other variables and files.  Due to the nature of stream networks, the dimenions in channel route out are linear and difficult to subset.  This code aims to simplify and automate the process.    


**prerequisites:**   This bash code utilizes 
1. netCDF operators `ncks`, `ncpdq` netCDF operators (Zender,  nco.sf.net) 
2. `cdo`: Climate Dataset Operators (code.mpimet.mpg.de/projects/cdo) 
3. `gsutil`  cloud.google.com/storage/docs/gsutil   (only required for `get_from_archives.sh` )


## getting started

Once the prerequisitites are installed, I'd suggest starting with `simple_get_nwm_flows.sh` in order to get a basic understanding of how this utility works.  This script has limited functionality (it only acquires analysis data for a single day) but is also much more concise and understandable than the full-fledged versions.

The one task that is not covered (but essential) is determining the feature_ids for the stream segments for which you desire streamflow information.  There are many nuances to this task but one method to determine all the inflows to a given body of water is by intersecting the stream network with a spatialPolygon of the shoreline.  This is illustrated in my other repo [networktrace](https://github.com/brotherJ4mes/network_trace)  

Once the feature_ids are determined they are placed, each on a newline, in the file `ids.txt`.  A sample file is included which contains the feature_ids for the major river inflows into Lake Chaplain in North America.

This other two scripts apply the same methods but acquire the analysis, short-range deterministic forecast and medium-range ensemble forecasts.   They are basically complicated looped versions of the simple version.  The two scripts differ in their intended use:

1. `get_nwm_flow.sh` acquires streamflow data from nomads.ncep.noaa.gov and is intended to be used in "real-time" since data access at nomads is limited to today and yesterday.  I developed this script to run on a cron and check for, acquire and process data every 6 hours.  

2. `get_archived_flows.sh` acquires streamflow data from the google cloud which allows a much broader time range of data.  It's intended use is for hindcasts, reforecasts, research, etc.


---
**contact:** james.kessler@noaa.gov
~                                                                                                                                                    
~                                                                                                                                                    
~                                           
