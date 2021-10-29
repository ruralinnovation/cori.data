#' Compare dimensions of tables on the database
#'
#' @param table_names A character vector of table names
#' @param con A valid database connection
#'
#' @return A data frame (data.table) containing the table name, count of rows, and count of columns
#' @export
#'
compare_dimensions <- function(table_names, con){

  dims <- data.table::rbindlist(lapply(table_names, get_dims, con = con))
  dims

}

#' Get the dimensions of a table on the database
#'
#' @param table_name The name of table on the database
#' @param con A database connection
#'
#' @return A one row data frame with the table name, a row count, and a column count
#' @export
#'
#' @importFrom DBI dbGetQuery
#' @importFrom glue glue_sql
#' @importFrom data.table data.table
#'
get_dims <- function(table_name, con){

  stopifnot(is.character(table_name))


  row_count <- DBI::dbGetQuery(con, glue::glue_sql("select count(*) as count from {`table_name`}", .con = con))
  col_count <- ncol(DBI::dbGetQuery(con, glue::glue_sql("select * from {`table_name`} limit 0", .con = con)))

  return(data.table::data.table(table = table_name, n_rows = row_count[['count']], n_cols = col_count))

}

