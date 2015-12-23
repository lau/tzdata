Tzdata
======

[![Build
Status](https://travis-ci.org/lau/tzdata.svg?branch=master)](https://travis-ci.org/lau/tzdata)

Tzdata. The [timezone database](https://www.iana.org/time-zones) in Elixir.

Extracted from the [Calendar](https://github.com/lau/calendar) library.

As of version 0.5.4 the tz release 2015g
is included in the package.

When a new release is out, it will be automatically downloaded.

The tz release version in use can be verified with the following function:

```elixir
iex> Tzdata.tzdata_version
"2015f"
```

## Getting started

Use through the [Calendar](https://github.com/lau/calendar) library
or directly: it is available on hex as `tzdata`.

```elixir
defp deps do
  [  {:tzdata, "~> 0.5.6"},  ]
end
```

The Tzdata app must be started. This can be done by adding :tzdata to
the applications list in your mix.exs file. An example:

```elixir
  def application do
    [applications: [:logger, :tzdata],
    ]
  end
```

## Data directory and releases

The library uses a file directory to store data. By default this directory
is `priv`. In some cases you might want to use a different directory. For
instance when using releases.  If so create the directory, make sure Elixir
can read and write to it. Then use elixir config files like this to tell
Tzdata to use that directory:

```elixir
config :tzdata, :data_dir, "/etc/elixir_tzdata_data"
```

You can choose to add the `release_ets` directory from `priv` to that directory
containing the `20xxx.ets` file that ships with this library.
If not, Tzdata will try to download data from iana.org at startup.

## Automatic data updates

By default Tzdata will poll for timezone database updates every day.
In case new data is available, Tzdata will download it and use it.

This feature can be disabled with the following configuration:

```elixir
config :tzdata, :autoupdate, :disabled
```

## Changes from 0.1.x

The 0.5.1+ versions uses ETS tables and automatically polls the IANA
servers for updated data. When a new version of the timezone database
is available, it is automatically downloaded and used.

For use with [Calendar](https://github.com/lau/calendar) you can still
specify tzdata ~> 0.1.7 in your mix.exs file in case you experience problems
using version ~> 0.5.2.

## Documentation

Documentation can be found at http://hexdocs.pm/tzdata/

## When new timezone data is released

IANA releases new versions of the [timezone database](https://www.iana.org/time-zones) frequently.

For users of Tzdata version 0.5.x+ the new database will automatically
be downloaded, parsed, saved and used in place of the old data.

## License

The tzdata Elixir library is released under the MIT license. See the LICENSE file.

The tz database files (found in the source_data directory) is public domain.
