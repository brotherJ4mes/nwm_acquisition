**prerequisites:**   This bash code utilizes 
1. netCDF operators `ncks`, `ncpdq` netCDF operators (Zender,  nco.sf.net) 
2. `cdo`: Climate Dataset Operators (code.mpimet.mpg.de/projects/cdo) 
3. `gsutil`  cloud.google.com/storage/docs/gsutil   (only required for `get_from_archives.sh` )


## getting started

Once the prerequisitites are installed, I'd suggest starting with `simple_get_nwm_flows.sh` in order to get a basic understanding of how this utility works.  This script has limited functionality (it only acquires analysis data for a single day) but is also much more concise and understandable than the full-fledged versions.

This other two scripts apply the same methods but acquire the analysis, short-range deterministic forecast and medium-range ensemble forecasts.   They are basically complicated looped versions of the simple version.  The two scripts differ in their intended use:

1. `get_nwm_flow.sh` acquires streamflow data from nomads.ncep.noaa.gov and is intended to be used in "real-time" since data access at nomads is limited to today and yesterday.  I developed this script to run on a cron and check for, acquire and process data every 6 hours.  

2. `get_archived_flows.sh` acquires streamflow data from the google cloud which allows a much broader time range of data.  It's intended use is for hindcasts, reforecasts, research, etc.


---
**contact:** james.kessler@noaa.gov
~                                                                                                         