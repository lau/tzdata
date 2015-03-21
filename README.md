Tzdata
======

[![Build
Status](https://travis-ci.org/lau/tzdata.svg?branch=master)](https://travis-ci.org/lau/tzdata)

Tzdata. The timezone database in Elixir.

Extracted from the [Kalends](https://github.com/lau/kalends) library.

As of version 0.0.2 the tz release 2015b (from 2015-03-19 23:28:11 -0700)
is used. The tz release version can be verified with the following function:

```elixir
    iex> Tzdata.TimeZoneDataSource.tzdata_version
    "2015b"
```

## License

The tzdata Elixir library is released under the MIT license. See the LICENSE file.

The tz database files (found in the source_data directory) is public domain.
