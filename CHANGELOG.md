# Changelog for Tzdata

## [0.5.17] - 2018-06-18
### Changes
- New PeriodBuilder implementation (Paul Swartz)
- tz release that ships with Tzdata is now 2018e instead of 2017b

## [0.5.16] - 2018-01-18
### Fixed
- Fix could not load 2018a release by removing obsolete reference to pacificnew file. (Johannes Weißl)

## [0.5.15] - 2018-01-07
### Fixed
- If no release file is present at a custom data dir location, copy the .ets file that ships with Tzdata
  to the custom data dir location. Avoids crashes when no .ets files are present at startup.

## [0.5.14] - 2017-11-22
### Fixed
- Follow redirects when downloading from IANA.
  Use
  https://data.iana.org/time-zones/tzdata-latest.tar.gz instead of
  https://www.iana.org/time-zones/repository/tzdata-latest.tar.gz

## [0.5.13] - 2017-11-12
### Fixed
- Handle varying Last-Modified headers from IANA.org for same relase. For avoiding these errors:

      Elixir.ArgumentError: argument error
      Module "ets", in :ets.new/2
      File "lib/tzdata/data_builder.ex", line 11, in Tzdata.DataBuilder.load_and_save_table/0

## [0.5.12] - 2017-04-16
### Changed
- Ships with tz data version 2017b instead of 2016c
- When checking for updated tz data, use Last Modified header

### Fixed
- Fix Elixir 1.5 warnings (Gal Tsubery)
- Fix issue with missing directories (Fabien Henon)

## [0.5.11] - 2017-03-07
### Changed
- For auto update use GET to find the file size if the headers do not have a Content-Length

## [0.5.10] - 2016-12-24
### Fixed

- Avoid handle_info errors in Elixir 1.4.0-rc.1 by using send_after and handle_info instead of Task in ReleaseUpdater. (Josh Bodah)

## [0.5.9] - 2016-08-12
### Changed

- Period building extended by 2 years and a use of a hard coded cut off time for handling far future datetimes changed to be based on compile time.

### Fixed

- Supress :random deprecated warning. We want to preserve compatability with older versions of Elixir and Erlang.

## [0.5.8] - 2016-06-05
### Changed

- Improve error handling for malformated contents of the "latest_remote_poll.txt" file

## [0.5.7] - 2016-03-23
### Changed

- Ship with tz data version 2016c

### Fixed

- Get rid of Elixir warnings in Elixir 1.3.0-dev

## [0.5.6] - 2015-12-23
### Fixed
- Get rid of Elixir warnings

## [0.5.5] - 2015-11-19
### Added
- Configurable location for data directory.
  e.g. `config :tzdata, :data_dir, "/etc/elixir_tzdata_data"`

## [0.5.4] - 2015-10-06
### Added

- Added option to disable data autoupdate (Martin Schürrer)
- Updated prepackaged data file from 2015f to 2015g

## [0.5.3] - 2015-09-24
### Added

- Logging of events related to updating the database

### Changed

- Get rid of HTTPoison dependency in favour of using Hackney directly.

## [0.5.2] - 2015-09-08
### Fixed

Hardcoded paths would cause problems if moving tzdata
to another location after compilation (Saša Jurić).

## [0.5.1] - 2015-08-18
### Fixed

Now looks for and stores files in its own dir, even when a dependency.

## [0.5.0] - 2015-08-17
### Changed

Changes the structure from using macros to using ETS tables
for storing the data.

This adds httpoison as a dependency.

### Added

Automatic updates of the timezone data runtime over the internet.

### Fixed

The ~2GB RAM limit for compilation is no longer in place.

## [0.1.7] - 2015-08-11
### Changed

Use data release 2015f as source data.

## [0.1.6] - 2015-06-14
### Changed

Use data release 2015e as source data.

## [0.1.5] - 2015-04-24
### Changed

Use data release 2015d as source data.

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
