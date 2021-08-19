# NetgearRouter

This package queries a Netgear cable modem, specifically an Orbi CBR750.
This gets the contents of the log and also the modem status information including the channels,
power, signal-to-noise ratio, number of errors.
I use this to help diagnose disconnects, looking at the power levels when the disconnects occur.

```
getLog(password)
getChannelInfo(password)
```


To avoid reconnecting, we can create and reuse the same connection, e.g.,
```
con = getCon(password)
log = getLog(con = con)
info = getChannelInfo(con = con)
```


`getLog()` returns the lines from the log file. It currently doesn't identify the type of log
message. I might do this in the future.

`getChannelInfo` returns 5 data.frames: 
+ the startup procedure status and comments, 
+ the downstream bonded channels
+ the upstream bonded channels
+ the downstream OFDM channels
+ the upstream OFDM channels

