#' Install the cori.data.* companion packages
#'
#' Installs the `cori.data.*` packages that provide read/write access to
#' specific public data sources on top of `cori.data`: Business Dynamics
#' Statistics, Business Formation Statistics, Building Permits Survey, FCC
#' broadband deployment data, Housing Unit estimates, Population Estimates,
#' and Quarterly Census of Employment and Wages.
#'
#' These are declared in `Suggests`, not `Imports`/`Depends`, because most of
#' them already depend on `cori.data` (for [connect_to_s3()]) -- listing them
#' as hard dependencies of `cori.data` itself would create a circular
#' dependency that R's namespace loader cannot resolve. This function is the
#' explicit, one-line alternative: run it right after installing `cori.data`
#' to pull in the rest of the suite.
#'
#' @param packages Character vector of package names to install. Default:
#'   all seven `cori.data.*` companion packages.
#' @param ... Additional arguments passed to `remotes::install_github()`.
#'
#' @return Invisibly, the character vector of packages installed.
#'
#' @examples
#' \dontrun{
#' cori.data::install_data_packages()
#'
#' # Install just one or two
#' cori.data::install_data_packages(c("cori.data.bds", "cori.data.qcew"))
#' }
#'
#' @export
install_data_packages <- function(packages = c(
                                    "cori.data.bds",
                                    "cori.data.bfs",
                                    "cori.data.bps",
                                    "cori.data.fcc",
                                    "cori.data.hu",
                                    "cori.data.pep",
                                    "cori.data.qcew"
                                  ), ...) {
  if (!requireNamespace("remotes", quietly = TRUE)) {
    stop("The 'remotes' package is required to install these packages. ",
         "Install it with install.packages('remotes').", call. = FALSE)
  }

  repos <- paste0("ruralinnovation/", packages)
  remotes::install_github(repos, ...)

  invisible(packages)
}
