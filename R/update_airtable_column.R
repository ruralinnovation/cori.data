#' Update an existing airtable column from R
#'
#' @param dta A data frame
#' @param record_id_col Unquoted name of the column corresponding to the airtable record ID
#' @param data_col Unquoted name of the column to update
#' @param api_key Airtable API key
#' @param base_id The ID of the airtable base
#' @param table_name Name of the airtable table to update
#' @param variable_name Name of the variable to update
#' @param type Data type, one of character, numeric, or multi_select
#'
#' @export
#'
#' @import dplyr
#' @importFrom purrr walk2
update_airtable_column <- function(dta,
                                   record_id_col,
                                   data_col,
                                   api_key,
                                   base_id,
                                   table_name,
                                   variable_name,
                                   type = c("character", "numeric", "multi_select")){
  # capture unquoted variable names
  # rid      <- rlang::enexpr(record_id_col)
  # data_col <- rlang::enexpr(data_col)

  # clean up any spaces in the table name
  table_name <- gsub("\\s+", "%20", table_name, perl = TRUE)

  # match type argument. Defaults to string
  data_type <- match.arg(type)

  # create base URL
  base_url <- sprintf(" https://api.airtable.com/v0/%s/%s/", base_id, table_name)

  # define the command format based on the data type
  at_vars_command_fmt <- switch(data_type,
                                string = '"%s": "%s"', # if string, everything captured in double quotes
                                numeric = '"%s": %s', # if numeric, only variable name captured in double quotes
                                multi_select = '"%s": [%s]' # if multi select, variable captured in brackets
  )

  # subset and clean up the data
  dta <- dplyr::select(dta, airtable_id = {{ record_id_col }}, update_dta = {{ data_col }}) %>%
    dplyr::mutate(at_vars_command = sprintf(at_vars_command_fmt, variable_name, .data$update_dta))
  # browser()
  # return(dta)
  purrr::walk2(dta$airtable_id, dta$at_vars_command, function(airtable_id, at_vars_command){

    command = paste0("curl -v -X PATCH ", base_url, airtable_id, " \ -H \"Authorization: Bearer ", api_key,"\" \ -H \"Content-Type: application/json\" --data '{\"fields\": {", at_vars_command, "}}'"
    )

    system(command, intern = TRUE, ignore.stderr = TRUE)
  })



}
