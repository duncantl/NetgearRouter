
getLog =
function(password = getOption("RouterPassword", stop("Need password")), ...,
         con = getCon(password, ...))
{
    txt = tryCatch(getURLContent("http://192.168.1.1/FW_log.htm", curl = con, referer = "http://192.168.1.1/start.htm"),
                   error = function(e) {
                      getURLContent("http://192.168.1.1/FW_log.htm", curl = con, referer = "http://192.168.1.1/start.htm")
                   })
    doc = htmlParse(txt)
    a = getNodeSet(doc, "//textarea")[[1]]
    log = xmlValue(a)
    mkLog(strsplit(log, "\\n")[[1]])
}

mkLog =
function(ops)
{
    ops = ops[ ops != "" ]
    type = gsub("^\\[([^]]+)\\] .*", "\\1", ops)
    dhcp = grepl("^DHCP IP", type)
    type[ dhcp ] = "DHCP"
    tm = gsub(".* (Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday .*)", "\\1", ops)
    ops = gsub(", ?(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday), .*", "", ops)
    ops[dhcp] = gsub("(\\[DHCP IP:|\\])", "", ops[dhcp])
    ops = gsub("^\\[[^]]+\\] ", "", ops)

    data.frame(operation = type,
               time = strptime(tm, "%A, %b %d,%Y %H:%M:%S"),
               info = ops)
}


getChannelInfo =
function(password = getOption("RouterPassword", stop("Need password")), ..., con = getCon(password, ...))
{
    #    referer = "http://192.168.1.1/cable_connection.htm"
    # have to make request twice as the first one says Unauthorized, but then makes a HTPP 1.0 request.
    tt = tryCatch(getURLContent("http://192.168.1.1/cable_connection.htm",  curl = con, referer = "http://192.168.1.1/start.htm"),
                  error = function(e)
                            getURLContent("http://192.168.1.1/cable_connection.htm",  curl = con, referer = "http://192.168.1.1/start.htm"))
    doc = htmlParse(tt)
    z = xmlValue(getNodeSet(doc, "//script[contains(., 'var strUSTable')]")[[1]])


    
#    down = gsub('.*var strDSTable = "([^"]+)";.*', "\\1", z)
    m = gregexpr('var [a-zA-Z]+ = "[^"]+";', z)
    tmp = regmatches(z, m)[[1]]
    vals = gsub('^[^"]+', '', tmp)
    vals = substring(vals, 2, nchar(vals)-2L)
    names(vals) = gsub("^str", "", gsub('.*var ([a-zA-Z]+) = ".*', "\\1", tmp))
    vals = grep("|", vals, fixed = TRUE, value = TRUE)
    makeTables(vals)
}

makeTables =
function(text)
{
    mapply(mkTable, text, ColumnNames[ names(text) ])
}

ColumnNames =
 list(DocsisInfo = c("Status", "Comment"),
      DSTable = c("Channel", "LockStatus", "Modulation", "ChannelID", "Frequency", "Power", "SNR", "Correctables", "Uncorrectable"),
      USTable = c("Channel", "LockStatus", "USChannelType", "ChannelID", "SymbolRate", "Frequency", "Power"),
      DSOfdmTable = c("Channel", "LockStatus", "Modulation/ProfileID", "ChannelID", "Frequency", "Power", "SNR/MER", "ActiveSubcarrierRange", "UnerroredCodewords", "CorrectableCodewords", "UncorrectabeCodeworkds"),
      USOfdmaTable = c("Channel", "LockStatus", "ModulationProfileID", "ChannelID", "Frequency", "Power"))

mkTable =
function(str, varNames = character())
{
    els = strsplit(str, "|", fixed = TRUE)[[1]]
    nrow = as.integer(els[1])
    if(nrow > 1000) {
        els = els[-11]
        els = els[els != ""]
        els = els[-(13:14)] # if these are 1, then we have extra information in the other tables.
        as.data.frame(matrix(els, , 2, byrow = TRUE, dimnames = list(c("Acquire Downstream Channel", "Connectivity State", "Boot State", "Configuration File", "Security Status", "IP Provisioning Mode"),
                                                        c("Status", "Comment"))))
    } else {
        ans = as.data.frame(matrix(els[-1], nrow, byrow = TRUE))
        ans[] = lapply(ans, type.convert, as.is = TRUE)
        if(length(varNames))
            names(ans) = varNames
        ans
    }
}

getCon =
function(password = getOption("RouterPassword", stop("Need password")), ...,
         con = getCurlHandle(cookiejar = "", followlocation = TRUE, username = "admin", password = password, useragent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:92.0) Gecko/20100101 Firefox/92.0", ...))    
{
    getURLContent('http://192.168.1.1', curl = con)
    con
}




checkDownstream =
function(dsTable)    
{
  locked = dsTable$LockStatus == "Locked"
  snr = range(dsTable$SNR[ locked  ])
  power = range(dsTable$Power[ locked  ])
  ans = c(power = TRUE, snr = TRUE, packets = TRUE)

  if(power[1] < -15 || power[2] > 15) #XXX || diff(power) > 3) # last comparison should be db not dbmv
      ans["power"] = FALSE

  if(diff(snr) > 3)
      ans["snr"] = FALSE
  else 
      ans["snr"] = all(snr[dsTable$Power[locked] < -6] > 33 & snr[dsTable$Power[locked] >= -6] > 30)

  ans["packets"]  = all(dsTable$Uncorrectable[locked]/dsTable$Correctables[locked] < .2)
  
  ans
}



traffic =
function(password = getOption("RouterPassword", stop("Need password")), ...,
         con = getCurlHandle(cookiejar = "", followlocation = TRUE, username = "admin", password = password, useragent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:92.0) Gecko/20100101 Firefox/92.0", ...))    
{
    tt = tryCatch(getURLContent("http://192.168.1.1/traffic_meter_cable.htm", curl = con),
                  error = function(e)
                      getURLContent("http://192.168.1.1/traffic_meter_cable.htm", curl = con))

    doc = htmlParse(tt)
    tbl = readHTMLTable(doc, which = 3, header = TRUE, skip = 1)

    fixTrafficTable(tbl)
}

fixTrafficTable =
function(tbl)
{    
    i = grep("/Avg", names(tbl))
    tbl[gsub("/Avg", "Avg", names(tbl)[i])] = lapply(tbl[i], function(x) { tmp = rep(as.numeric(NA),  length(x)); tmp [ grep("/", x) ] = as.numeric(gsub(".*/", "", x[ grep("/", x) ])); tmp})
    tbl[i] = lapply(tbl[i], function(x) as.numeric(gsub("/.*", "", x)))

    names(tbl) = gsub("/Avg", "", names(tbl))
    tbl
}


statistics =
function(password = getOption("RouterPassword", stop("Need password")), ...,
         con = getCurlHandle(cookiejar = "", followlocation = TRUE, username = "admin", password = password, useragent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:92.0) Gecko/20100101 Firefox/92.0", ...))    
{
    tt = tryCatch(getURLContent("http://192.168.1.1/RST_stattbl.htm", curl = con),
                  error = function(e)
                         getURLContent("http://192.168.1.1/RST_stattbl.htm", curl = con))
    doc = htmlParse(tt)
    tbl = readHTMLTable(doc, which = 3, header = TRUE)#, skip = 1)
    tbl$UpTime = parseTime(tbl$"Up Time")
    tbl
}

parseTime =
function(x)
{
    ans = rep(as.numeric(NA), length(x))
    w = which(x != "--")
    x[w] = gsub(" days ", ":", x[w])
    ans[w] = sapply(strsplit(x[w], ":"), function(x) sum(as.integer(rev(x))* c(seconds = 1, minutes = 60, hours = 60*60, days = 24*60*60)[seq(along.with = x)]))

    ans
}
