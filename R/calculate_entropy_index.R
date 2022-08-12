#' Calculate Theils_H segregation measure
#'
#' @param df A data frame containing a base geoid, the specified grouping variables, and a total population variable
#' @param base_geoid Lowest common geographic level. `agg_geoid` must inherit from `base_geoid` (e.g. tract -> county, county -> state, etc.)
#' @param agg_geoid Geographic level to aggregate to.
#' @param geoid_crosswalk Crosswalk defining relationship between `base_geoid` and `agg_geoid`
#' @param group_vars A set of grouping variables that must total to the value contained in `total_pop_var`
#' @param total_pop_var The total population for the base geography
#'
#' @return A data frame with four fields, `agg_geoid`,  `entropy_score`, `entropy_index`, `cnt_{base_geoid}_in_{agg_geoid}`
#'
#' @export
#'
#' @importFrom magrittr `%>%`
#' @importFrom data.table `:=`
#'
calculate_entropy_index <- function(df,
                                    base_geoid,
                                    agg_geoid,
                                    geoid_crosswalk,
                                    group_vars,
                                    total_pop_var){
  # resolving NSE CMD check errors
  E <- agg_E <- base_E <- h <- NULL

  vars <- c(group_vars, total_pop_var)

  base_df_assets <- c(base_geoid, vars)

  out <- df %>%
    dplyr::select(dplyr::all_of(base_df_assets)) %>%
    dplyr::left_join(geoid_crosswalk, by = base_geoid)

  agg_df <- out %>%
    dplyr::group_by(!!as.name(agg_geoid)) %>%
    dplyr::summarise(dplyr::across(dplyr::all_of(vars), ~ sum(.x, na.rm = TRUE))) %>%
    dplyr::mutate(
      check = rowSums(dplyr::across(dplyr::all_of(group_vars))) == !!as.name(total_pop_var)
    )

  if(!all(agg_df$check)){
    stop("Group population total is not equal to the specified total population variable")
  }


  all_vars_agg <- lapply(group_vars, function(v){

    select_vector <- c(agg_geoid, total_pop_var, v)

    agg_df %>%
      dplyr::select(select_vector) %>%
      dplyr::mutate(
        !!paste0(v, '_share') := !!as.name(v) / !!as.name(total_pop_var),
        !!paste0(v, '_E') := !!as.name(paste0(v, '_share')) * log(1 / !!as.name(paste0(v, '_share'))),
      ) %>%
      dplyr::select(
        agg_geoid,
        !!as.name(total_pop_var),
        !!as.name(paste0(v, '_E'))

      )
  })

  agg_share <- purrr::reduce(all_vars_agg, dplyr::left_join, by = c(agg_geoid, total_pop_var))

  ## entropy score at the aggregate geography level - describes diversity in the aggregate geographic areas
  # The higher the number, the more diverse an area. The maximum level of entropy is
  # given by the natural log of the number of groups used in the calculations.
  # With six racial/ethnic groups, the maximum entropy is log 6 or 1.792.

  agg_share$E = rowSums(agg_share[, 3:ncol(agg_share)], na.rm = TRUE)

  agg_entropy_score <- agg_share %>%
    dplyr::select(
      agg_geoid,
      agg_E = E,
      !!paste0(total_pop_var, '_agg') := !!as.name(total_pop_var),
    )

  ## base geography
  all_vars_base <- lapply(group_vars, function(v){

    select_vector <- c(base_geoid, total_pop_var, v)

    out %>%
      dplyr::select(select_vector) %>%
      dplyr::mutate(
        !!paste0(v, '_share') := !!as.name(v) / !!as.name(total_pop_var),
        !!paste0(v, '_E') := !!as.name(paste0(v, '_share')) * log(1 / !!as.name(paste0(v, '_share'))),
      ) %>%
      dplyr::select(
        base_geoid,
        !!as.name(total_pop_var),
        !!as.name(paste0(v, '_E'))
      )
  })

  base_share <- purrr::reduce(all_vars_base, dplyr::left_join, by = c(base_geoid, total_pop_var))

  ## entropy score at the base geography level
  base_share$E = rowSums(base_share[, 3:ncol(base_share)], na.rm = TRUE)

  base_entropy_score <- base_share %>%
    dplyr::select(
      base_geoid,
      base_E = E,
      total_pop_var
    )

  theils_H <- geoid_crosswalk %>%
    dplyr::left_join(
      base_entropy_score, by= base_geoid
    ) %>%
    dplyr::left_join(
      agg_entropy_score, by= agg_geoid
    ) %>%
    dplyr::mutate(
      h = (
        (!!as.name(total_pop_var) * (agg_E - base_E)
        ) /
          (agg_E * !!as.name(paste0(total_pop_var, '_agg')))
      )
    ) %>%
    dplyr::group_by(
      !!as.name(agg_geoid), entropy_score = agg_E
    ) %>%
    dplyr::summarise(
      entropy_index = sum(h, na.rm = TRUE),
      !!paste0('cnt_',base_geoid,'_in_', agg_geoid) := dplyr::n()
    )


    return(theils_H)
}
