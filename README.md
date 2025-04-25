## CORI/RISI data sets and data functions

![lifecycle](https://img.shields.io/badge/lifecycle-maturing-blue.svg)

### Part of the [coriverse](https://github.com/ruralinnovation/coriverse/wiki)

This is an internal meta package linking packages of useful data sets and functions that can be used to create (generate) or augment data (i.e. geocoding).

~~This also serves as cache (temporary) for some commonly referenced geographic data sets.~~

## Setup for Development

Once you have all of the dependencies installed, to build and install this package from the local project directory, run:
```r
pkgbuild::clean_dll(); pkgbuild::compile_dll(); devtools::document(); devtools::check(); devtools::install();
```
