# Changelog for Tzdata

## [1.0.5] - 2020-11-27

### Fixed

- Fix issues with Tzdata.TimeZoneDatabase during gaps (Benjamin Milde)

### Changed

- tzdata release version shipped with this library is now 2020d instead of 2019c.

## [1.0.4] - 2020-10-07

### Fixed

- Fix warning in Elixir 1.11 (Thanabodee Charoenpiriyakij)

## [1.0.3] - 2019-12-19

### Changed

- tzdata release version shipped with this library is now 2019c instead of 2019a.

### Fixed

- Hackney was not set as an "application" in non-dev environments in 1.0.2 and could cause errors in updating.

## [1.0.2] - 2019-10-17

### Fixed

- Avoid creating atoms for non-existing time zone names.

## [1.0.1] - 2019-07-01

### Fixed

- Fixed: could not process 2019b release. Error related to `first_matching_weekday_in_month(1932, 4, 7, [])`.

## [1.0.0] - 2019-04-23

### Changed

- Elixir version requirement increased to Elixir 1.8+
- ETS table normalization for performance improvements over 0.5.x releases
- .ets release files now have contents with a different structure
- Because of the different structre the .ets files now have a different file ending. E.g.: 2019a.v2.ets

### Added

- Tzdata.TimeZoneDatabase module that implements the Calendar.TimeZoneDatabase behaviour.

Changelog for v0.5.x releases can be found [in the pre_1-8 branch](https://github.com/lau/tzdata/blob/pre_1-8/CHANGELOG.md).
