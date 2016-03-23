# Changelog for Tzdata

## [0.1.201603] - 2016-03-23
### Changed

Use data release 2016c as source data.

## [0.1.201601] - 2016-02-23
### Changed

Use data release 2016a as source data.

## [0.1.8] - 2015-10-07
### Changed

Use data release 2015g as source data.

## [0.1.4] - 2015-04-23
### Changed

Removed redundant files that were present in 0.1.3 release on hex.

## [0.1.3] - 2015-04-14
### Changed

Use data release 2015c as source data.

## [0.1.2] - 2015-04-11
### Changed

Only precompile timezone period information about 40 years into the future
instead of 80 years into the future. With 80 years compiling tzdata would fail
on some machines with 1GB of RAM.

## [0.1.1] - 2015-04-09
### Added

- Support for DST in the far future for all timezones. Before there was
  a limit up to the year 2200. Now years over 10000 should work.

- "Caching" added for wall time datetimes in `periods_for_time`.
  Via macro generated functions that were also available for :utc before.
  Basically the same thing has been added for :wall times.

### Changed

- A dynamic period finder for the far future has been added.
  The is now used for periods for points in time that are 80 years after
  compile time or later. This means that the amount of pregenerated/cached periods
  have been reduced to cover up until 80 years after compile time.

- The macro-generated cached `periods_for_time` functions that are specific
  for a certain range of times now cover from 2014 until 10 after compile time.
  And as noted in the "Added" section now also cover wall times.

- The general `periods_for_time` function does not use the Access way of
  accessing maps anymore. This change seems to have made it a bit quicker.

## [0.1.0] - 2015-04-03
### Added

Added parsing of zone1970.tab file. This provides info about which timezones
applies in which countries.

Added leap second information.

### Changed

`Tzdata.TimeZoneDataSource` module removed! It is replaced by just `Tzdata`. All
of the function of `TimeZoneDataSource` has been moved to the `Tzdata` module.

Removed :wall as default argument in `periods_for_time` function.
