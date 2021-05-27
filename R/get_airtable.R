#' Get table from Airtable
#'
#' @param key API key
#' @param base Airtable base to connect to
#' @param table Airtable table name
#' @param view Airtable view to connect to. Defaults to 'All'
#' @param max_records Maximum number of records to return
#' @param print Optionally print diagnostics along the way. Defaults to FALSE
#'
#' @return A data.frame
#' @export
#'
#' @import httr
#' @import jsonlite
#' @import dplyr
get_airtable = function(key, base = "appD6byygamXxc3jx", table, view = "All", max_records = 500, print = FALSE){

  # set local vars for pagination
  table = gsub(" ", "%20", table)
  pages = ceiling(max_records/100)-1
  offset=0

  if (print)(print(paste0("# of Pages:  ", pages)))

  # requests for more than 100 records from airtable requires pagination
  for(k in 0:pages) {

    #print(paste0("Page: ", k))

    base_fmt = 'https://api.airtable.com/v0/%s/'

    # GET request for page X from Airtable
    path = paste0(sprintf(base_fmt, base), table, "?");
    path;
    request = GET(url = path,
                  query = list(
                    max_records = max_records,
                    view = view,
                    offset = offset,
                    api_key = key
                  )
    )

    # CONVERT to data frame and get offset for next page
    response <- httr::content(request, as = "text", encoding = "UTF-8")
    temp <- jsonlite::fromJSON(response, flatten = TRUE) %>% data.frame(stringsAsFactors = F)
    offset <- jsonlite::fromJSON(response)$offset

    # COMBINE pages into a single data frame
    if(k==0){ airtable_all <- temp }
    else{ airtable_all = bind_rows(airtable_all, temp) }


  }

  # airtable will contain duplicates if max records is greater than actual records
  # so remove duplicates

  airtable_final = airtable_all
  airtable_final = airtable_final[!duplicated(airtable_final),]


  if(print){
    cat(paste0("\n\n", paste(replicate(110, "*"), collapse = "")))
    cat(paste0("\n", paste(replicate(110, "*"), collapse = ""), "\n"))
    cat(paste0("\n", "         Airtable Base: ", base, "\n"))
    cat(paste0("\n", "        Airtable Table: ", table, "\n"))
    cat(paste0("\n", "        Airtable  View: ", view, "\n"))
    cat(paste0("\n", "# of records requested: ", max_records, "\n"))
    cat(paste0("\n", " # of records returned: ", nrow(airtable_final), "\n"))
    cat(paste0("\n", paste(replicate(110, "*"), collapse = ""), ""))
    cat(paste0("\n", paste(replicate(110, "*"), collapse = ""), "\n\n"))

  }

  return(airtable_final)
}
