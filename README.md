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

### `getLog()` returns a data frame with 3 columns.
+ the type of the log message
+ the time-date stamp
+ the information in the message.


### `getChannelInfo()` returns 5 data.frames: 
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

### `traffic` returns a data.frame
with rows corresponding to diferent time periods (today, yesterday, week, month, previous month).
The columns include
+ the upload and download totals in megabytes
+ the upload and download average 

### `statistics()` returns a data.frame with rows for each 
port (WAN, LAN1, LAN2, ..., 2.4G WLAN, 5G WLAN, WLAN Backhaul).
The columns include
+ status
+ the number of transmitted and received packets, separately
+ the number of collisions
+ the transmit and receive bytes per second
+ the up-time both in human readable form and number of seconds.


### `cron()`
