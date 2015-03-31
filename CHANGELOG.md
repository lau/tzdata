# Changelog for Tzdata

## [0.1.0] - 2015-03-30
### Added

Added parsing of zone1970.tab file. This provides info about which timezones
applies in which countries.

### Changed

`Tzdata.TimeZoneDataSource` module removed! It is replaced by just `Tzdata`. All
of the function of `TimeZoneDataSource` has been moved to the `Tzdata` module.

