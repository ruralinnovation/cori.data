#' Read and de-normalize ACS data from Postgres
#'
#' @param con A database connection to the ACS schema
#' @param acs_table Name of the table to read from
#' @param variables A vector of variable names to read
#' @param years A vector of years to pull data for
#' @param variables_from Where to pull column names from, one of 'variable' or 'acs_code'
#' @param values_from Where to pull data values from, one of 'estimate' or 'moe'
#'
#' @return A de-normalized table, unique on geoid and year
#' @export
#'
#' @importFrom tidyr pivot_wider
#' @importFrom DBI dbGetQuery
#' @importFrom glue glue_sql
#'

read_acs <- function(con, acs_table, variables, years = 2019, variables_from = 'variable', values_from = 'estimate'){

  variables_from <- match.arg(variables_from, c('variable', 'acs_code'))
  values_from <- match.arg(values_from, c('estimate', 'moe'))

  acs_query <- glue::glue_sql("select * from {`acs_table`} where {`variables_from`} in ({variables*}) and year in ({years*})", .con = con)

  acs_data <- DBI::dbGetQuery(con, acs_query)

  geoid <- names(acs_data)[grepl("geoid", names(acs_data))]

  tidyr::pivot_wider(acs_data, id_cols = c(geoid, 'year'), names_from = variables_from, values_from = values_from)

  }
