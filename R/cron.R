FilenameFormat = "%Y_%m_%d_%H:%M:%S.rds"

mkFileName  =
function(date, format = FilenameFormat)
    format(date, format)

cron =
function(dir = getOption("RouterLogDirectory", "~/RouterLogs"),
         pwd = getOption("RouterPassword", stop("Need router password")),
         file = mkFileName(Sys.time()),
         locale = NA)
{
    if(!is.na(locale))
        Sys.setlocale(locale = locale)
    
    con = getCon(pwd)

    o = list(log = getLog(con = con),
             stat = statistics(con = con),
             traffic =  traffic(con = con),
             info = getChannelInfo(con = con))

    saveRDS(o, file.path(dir, file))
}


listFiles = 
function(dir = getOption("RouterLogDirectory", "~/RouterLogs"),
         files = list.files(dir, pattern = "\\.rds$", full.names = TRUE), ...)
    files

readLogs =
function(dir = getOption("RouterLogDirectory", "~/RouterLogs"),
         files = listFiles(dir, ...), ...)
{
    tmp = lapply(files, function(f) readRDS(f)$log)
    flog = do.call(rbind, tmp)
}

getDisconnects =
function(log, regex = "disconnected")
{
  con = flog[grep(regex, flog$operation), ]
       # but this has repetitions.
  ev = by(con, con$time, function(x) x[ !duplicated(x$info), ])
  do.call(rbind, ev)
}

findClosestFile =
function(date, dir = getOption("RouterLogDirectory", "~/RouterLogs"),
         files = list.files(dir, pattern = "\\.rds$", full.names = TRUE),
         format = FilenameFormat, ...)
{
    dates = getFileDates(files)

    i = max( which ( (date - dates) >  0 ) )
    files[ i ]
    
}

getFileDates =
function(files)    
{
    fn = basename(files)
    strptime(gsub("\\.rds$", "", fn), gsub("\\.rds$", "", FilenameFormat))
}

combineRDS =
function(el, dir = getOption("RouterLogDirectory", "~/RouterLogs"),
         files = listFiles(dir, ...), ...)    
{
    tmp = lapply(files, function(f) getEl(readRDS(f), el))
    dates = getFileDates(files)
    tmp = mapply(function(x, date) { x$time = date ; x},
                 tmp, dates, SIMPLIFY = FALSE)
    do.call(rbind, tmp)
}

getEl =
function(obj, el)
{
    for(i in el)
        obj = obj[[i]]

    obj
}
