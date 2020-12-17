Tzdata
======

[![Build Status](https://travis-ci.org/lau/tzdata.svg?branch=master)](https://travis-ci.org/lau/tzdata)
[![Hex.pm version](https://img.shields.io/hexpm/v/tzdata.svg)](http://hex.pm/packages/tzdata)
[![Hexdocs.pm](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/tzdata/)
[![Hex.pm downloads](https://img.shields.io/hexpm/dt/tzdata.svg)](https://hex.pm/packages/tzdata)
[![License](https://img.shields.io/hexpm/l/tzdata.svg)](https://github.com/lau/tzdata/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/lau/tzdata.svg)](https://github.com/lau/tzdata/commits/master)

The [time zone database](https://www.iana.org/time-zones) parser and library for Elixir.

Part of the source code extracted from the
[Calendar](https://github.com/lau/calendar) library.

As of version 1.0.5, the included tz release version is `2020d`.  New release
will be downloaded automatically during runtime.

To verify the current tz release version, run the following function:

```elixir
iex> Tzdata.tzdata_version
"2020d"
```

## Getting started

To use Tzdata library with Elixir 1.8, add `:tzdata` to the dependencies of the
`mix.exs` file:

```elixir
defp deps do
  [  {:tzdata, "~> 1.0.5"}  ]
end
```

To define a global time zone database for Elixir, put the following line in the
config file of your application:

```elixir
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
```

That's it!  You can now use the Elixir's `DateTime` library with Tzdata for all time zone
calculations.

One example is getting the current time of a certain time zone:

```elixir
iex> DateTime.now("Europe/Copenhagen")
{:ok, #DateTime<2018-11-30 20:51:59.076524+01:00 CET Europe/Copenhagen>}
```

Alternatively, you can define a time zone database manually. Pass the module
name `Tzdata.TimeZoneDatabase` directly to the function that need a time zone
database:

```elixir
DateTime.now("Europe/Copenhagen", Tzdata.TimeZoneDatabase)
```

## Data directory and releases

The library uses a data directory for storing time zone data. By default, this
is set to `priv`.  In some cases like releases, it's recommended to use a
different data directory.

For custom data directory, create a new directory and make sure Elixir can read
and write to it.  Put the following line in the config file of your
application:

```elixir
config :tzdata, :data_dir, "/etc/elixir_tzdata_data"
```

Add the `release_ets` directory from `priv` to that directory containing the
`20xxx.ets` file that ships with this library.

For instance, using the above config, an `.ets` file such as
`/etc/elixir_tzdata_data/release_ets/2017b.ets` should be present.

## Automatic data updates

By default, Tzdata will poll for time zone database updates on daily basis.  If
a new time zone database is available, Tzdata will download it and use it.

This feature can be disabled with the following configuration:

```elixir
config :tzdata, :autoupdate, :disabled
```

If the `:autoupdate` setting is set to `:disabled`, one has to manually update
`.ets` files in the `release_ets` sub-dir of the `:data_dir` (see the "Data
directory and releases" section above).  When IANA releases a new version of the
time zone data, this Tzdata library can be used to generate a new `.ets` file
containing the new data.

## Changes from 0.1.x to 0.5.x

The 0.5.1+ version uses ETS tables and automatically polls the IANA servers
for updated data. When a new version of the time zone database is available, it
is automatically downloaded and used.

For use with [Calendar](https://github.com/lau/calendar) you can still specify
`:tzdata ~> 0.1.7` in your `mix.exs` file in case you experience problems using
version `~> 0.5.20`.

## Hackney dependency and security

The Erlang's built-in HTTP client `httpc` does not verify SSL certificate and
make secure HTTPS request. Hence, Tzdata depends on `hackney` library to verify
the certificate of IANA when checking and getting a new time zone database
release.

## Documentation

Documentation can be found at http://hexdocs.pm/tzdata/

## When new time zone data is released

IANA releases a new version of the [time zone database](https://www.iana.org/time-zones) frequently.

For users of Tzdata version 0.5.x+, a new database will be automatically
downloaded, parsed, saved, and used in place of the old data.

## License

The tzdata Elixir library is released under the MIT license.  Copyright (c)
2014-present, Lau Taarnskov.  See the LICENSE file.

The tz database files (found in the `source_data` directory of early versions)
is public domain.
