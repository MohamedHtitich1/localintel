#' @title Session-Level Smart Cache
#' @description In-memory caching for expensive operations within an R session
#' @name cache
NULL

# Package-level cache environment
.localintel_cache <- new.env(parent = emptyenv())

#' Get Value from Session Cache (Internal)
#'
#' @param key Character cache key
#' @return Cached value or NULL if not found
#' @keywords internal
cache_get <- function(key) {
  if (exists(key, envir = .localintel_cache, inherits = FALSE)) {
    return(get(key, envir = .localintel_cache, inherits = FALSE))
  }
  NULL
}

#' Set Value in Session Cache (Internal)
#'
#' @param key Character cache key
#' @param value Value to cache
#' @keywords internal
cache_set <- function(key, value) {
  assign(key, value, envir = .localintel_cache)
  invisible(value)
}

#' Build Cache Key (Internal)
#'
#' Creates a deterministic cache key from function name and arguments
#'
#' @param fn_name Character function name
#' @param ... Arguments to hash
#' @return Character cache key
#' @keywords internal
cache_key <- function(fn_name, ...) {
  args <- list(...)
  paste0(fn_name, "_", paste(args, collapse = "_"))
}

#' Clear Session Cache
#'
#' Removes all cached data from the localintel session cache.
#' Useful when you want to force fresh data fetches from Eurostat,
#' for example after a NUTS classification update.
#'
#' @return Invisible NULL
#' @export
#' @examples
#' \dontrun{
#' # Force refresh of all cached geometries and references
#' clear_localintel_cache()
#' }
clear_localintel_cache <- function() {
  rm(list = ls(envir = .localintel_cache), envir = .localintel_cache)
  message("localintel session cache cleared.")
  invisible(NULL)
}
