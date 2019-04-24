# Changelog for Tzdata

## [1.0.0] - 2019-04-23

### Changed

- Elixir version requirement increased to Elixir 1.8+
- ETS table normalization for performance improvements over 0.5.x releases
- .ets release files now have contents with a different structure
- Because of the different structre the .ets files now have a different file ending. E.g.: 2019a.v2.ets

### Added

- Tzdata.TimeZoneDatabase module that implements the Calendar.TimeZoneDatabase behaviour.

Changelog for v0.5.x releases can be found [in the pre_1-8 branch](https://github.com/lau/tzdata/blob/pre_1-8/CHANGELOG.md).
