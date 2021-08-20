cron =
function(dir = getOption("RouterLogDirectory", "~/RouterLogs"),
         pwd = getOption("RouterPassword", stop("Need router password")),
         file = format(Sys.time(), "%Y_%m_%d_%H:%M:%S.rds"),
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
