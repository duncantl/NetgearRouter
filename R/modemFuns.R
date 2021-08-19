
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
    strsplit(log, "\\n")[[1]]
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
    names(vals) = gsub('.*var ([a-zA-Z]+) = ".*', "\\1", tmp)
    vals = grep("|", vals, fixed = TRUE, value = TRUE)
    lapply(vals, mkTable)
}


mkTable =
function(str)
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
