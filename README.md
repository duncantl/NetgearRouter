# NetgearRouter

This package queries a Netgear cable modem, specifically an Orbi CBR750.
This gets 
+ the contents of the log 
+ the modem status information including the channels, power, signal-to-noise ratio, number of
errors,
+ traffic volume
+ traffic statistics on the different ports
+ a function (cron) to collect all of these that can be used with cron/launchd daemons.

I use the channel power information to help diagnose disconnects, looking at the power & SNR levels when the disconnects occur.

The primary functions are 
```
getLog(password)
getChannelInfo(password)
statistics(password)
traffic(password)
cron()
```

If we are calling more than one of these functions, we can
create a single connection to the modem Web server and reuse that.
This avoids reconnecting for each call.  
```
con = getCon(password)
log = getLog(con = con)
info = getChannelInfo(con = con)
```

## Specifying the Password

To avoid having to specify the password in each call,
we can set it via the `RouterPassword` option in R's `options()`, i.e.,
```r
options(RouterPassword = "password")
```

You can specify this option in an R session or in your ~/.Rprofile script.
Make certain that others cannot read your ~/.Rprofile.

Setting the password in your ~/.Rprofile means that it is available
to the `cron()` function when called via launchd or crontab in non-interactive R sessions.


## The functions

### `getLog()`
Returns a data frame with 3 columns.
+ the type of the log message
+ the time-date stamp
+ the information in the message.


### `getChannelInfo()` 
Returns 5 data.frames: 
+ the startup procedure status and comments, 
+ the downstream bonded channels
+ the upstream bonded channels
+ the downstream OFDM channels
+ the upstream OFDM channels

Each of these has a different number of columns,
but each row corresponds to a channel.
The elements common to all of these data.frames are
+ Channel number
+ Channel ID
+ Locked Status
+ Frequency (in Hertz)
+ Power (in dBmV)

### `traffic` 
Returns a data.frame
with rows corresponding to diferent time periods (today, yesterday, week, month, previous month).
The columns include
+ the upload and download totals in megabytes
+ the upload and download average 

### `statistics()` 
Returns a data.frame with rows for each 
port (WAN, LAN1, LAN2, ..., 2.4G WLAN, 5G WLAN, WLAN Backhaul).
The columns include
+ status
+ the number of transmitted and received packets, separately
+ the number of collisions
+ the transmit and receive bytes per second
+ the up-time both in human readable form and number of seconds.


### `cron()`
Calls all of the functions above, collects the results into a list
and writes them to an RDS file.
This is used to collect the results at regular intervals.



## Launchd

On OSX, we can use launchctl to schedule a call to `cron()` at regular intervals.
The XML file specifying the task details is installed in the package as
local.getrouterinfo.plist. You can find it with
```r
system.file("local.getrouterinfo.plist", package = "NetgearRouter")
```

The shell commannds unload any existing version and load the current version:
```sh
launchctl unload local.getrouterinfo.plist 
launchctl load local.getrouterinfo.plist 
```

You can edit the XML .plist file to change the
+ interval between calls which defaults to 10 minutes
+ the directory in which the RDS files are saved
+ the locale for your router.

You can specify the director for the RDS files by omitting it from the call to `cron()` in the XML
file and setting
```r
options(RouterLogDirectory = "/path/to/directory")
```
(~ will be expanded appropriately.)


The locale defaults to UTF-8.  It is unclear whether you can change this on the router, 
and if not, this default makes sense.




## Reading the RDS files

There are functions to help read the RDS files and combine elements across RDS files.
These take the directory and read the RDS files, extract the relevant element and combines them.

`readLogs()` combines all of the log files. We use this to find when the modem disconnects and
reconnects from the ISP.
```r
log = readLogs()
dis = getDisconnects(log)
```
Then we find the RDS file that is closest to each of these dates
```r
before = unique(sapply(dis$time, findClosestFile))
[1] "/Users/duncan/RouterLogs/2021_08_20_10:45:36.rds"
[2] "/Users/duncan/RouterLogs/2021_08_20_21:27:15.rds"
```


We can read these files and combine the downstream

```
combineRDS(list("info", 2), files = before)
combineRDS(c("info", "DSTable"), files = before)
```
Note that this puts the date from the file into each row of the data.frame.

If we want to look at all of the downstream channel information, not just those before the
disconnects, we can call `combineRDS()` but without specifying the files. It will read all of the
RDS files.
```
ds = combineRDS(list("info", 2))
```
