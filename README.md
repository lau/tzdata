Tzdata
======

[![Build
Status](https://travis-ci.org/lau/tzdata.svg?branch=master)](https://travis-ci.org/lau/tzdata)
[![Hex.pm version](https://img.shields.io/hexpm/v/tzdata.svg)](http://hex.pm/packages/tzdata)
[![Hex.pm downloads](https://img.shields.io/hexpm/dt/tzdata.svg)](https://hex.pm/packages/tzdata)

Tzdata. The [timezone database](https://www.iana.org/time-zones) in Elixir.

Extracted from the [Calendar](https://github.com/lau/calendar) library.

As of version 1.1.3 the tz release 2025a is included in the package.

When a new release is out, it will be automatically downloaded at runtime.

The tz release version in use can be verified with the following function:

```elixir
iex> Tzdata.tzdata_version
"2024b"
```

## Getting started

To use the Tzdata library with Elixir 1.8+, add it to the dependencies in your mix file:

```elixir
defp deps do
  [  {:tzdata, "~> 1.1"},  ]
end
```

In your application you can choose to globally configure Elixir to use Tzdata.
This can be done by putting the following line in the config file of your application:

    config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

That's it!

That allows you to [use the Elixir standard library to use Tzdata to do time zone calculations](https://hexdocs.pm/elixir/DateTime.html#content).
One example is getting the current time in a certain time zone:

```elixir
iex> DateTime.now("Europe/Copenhagen")
{:ok, #DateTime<2018-11-30 20:51:59.076524+01:00 CET Europe/Copenhagen>}
```

If you do not want Elixir to have a time zone database globally defined you can instead pass
the module name `Tzdata.TimeZoneDatabase` directly to the functions that need a time zone database:

```elixir
DateTime.now("Europe/Copenhagen", Tzdata.TimeZoneDatabase)
```

## Data directory and releases

The library uses a file directory to store data. By default this directory
is `priv`. In some cases you might want to use a different directory. For
instance when using releases this is recommended. If so, create the directory and
make sure Elixir can read and write to it. Then use elixir config files like this
to tell Tzdata to use that directory:

```elixir
config :tzdata, :data_dir, "/etc/elixir_tzdata_data"
```

Add the `release_ets` directory from `priv` to that directory
containing the `20xxx.ets` file that ships with this library.

For instance with this config: `config :tzdata, :data_dir, "/etc/elixir_tzdata_data"`
an `.ets` file such as `/etc/elixir_tzdata_data/release_ets/2017b.ets` should be present.

## Automatic data updates

By default Tzdata will poll for timezone database updates every day.
In case new data is available, Tzdata will download it and use it.

This feature can be disabled with the following configuration:

```elixir
config :tzdata, :autoupdate, :disabled
```

If the autoupdate setting is set to disabled, one has to manually put updated .ets files
in the release_ets sub-dir of the "data_dir" (see the "Data directory and releases" section above).
When IANA releases new versions of the time zone data, this Tzdata library can be used to generate
a new .ets file containing the new data.

## Changes from 0.1.x to 0.5.x

The 0.5.1+ versions uses ETS tables and automatically polls the IANA
servers for updated data. When a new version of the timezone database
is available, it is automatically downloaded and used.

For use with [Calendar](https://github.com/lau/calendar) you can still
specify tzdata ~> 0.1.7 in your mix.exs file in case you experience problems
using version ~> 0.5.20

## HTTP Client

Tzdata uses Finch (via the Mint HTTP client) for HTTPS requests to get new updates. Finch provides secure HTTPS connections with proper SSL certificate verification when downloading new tzdata releases from IANA.

If you need to use a different HTTP client, you can implement the `Tzdata.HTTPClient` behaviour and configure it. See the source code for details.

## Migrating from Hackney

Previous versions of Tzdata used Hackney as the HTTP client. As of version 1.2.0, Finch is the default HTTP client.

If you need to continue using Hackney, you can:

1. Add `{:hackney, "~> 1.17"}` to your `mix.exs` dependencies
2. Configure tzdata to use Hackney:

```elixir
config :tzdata, :http_client, Tzdata.HTTPClient.Hackney
```

The Hackney implementation is still included in tzdata for backward compatibility.

## Documentation

Documentation can be found at http://hexdocs.pm/tzdata/

## When new timezone data is released

IANA releases new versions of the [timezone database](https://www.iana.org/time-zones) frequently.

For users of Tzdata version 0.5.x+ the new database will automatically
be downloaded, parsed, saved and used in place of the old data.

## License

The tzdata Elixir library is released under the MIT license. See the LICENSE file.

The tz database files (found in the source_data directory of early versions) is public domain.
