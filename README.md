Tzdata
======

[![Build
Status](https://travis-ci.org/lau/tzdata.svg?branch=master)](https://travis-ci.org/lau/tzdata)

Tzdata. The [timezone database](https://www.iana.org/time-zones) in Elixir.

Extracted from the [Calendar](https://github.com/lau/calendar) library.

As of version 0.5.1 the tz release 2015f (from 2015-08-10 18:06:56 -0700)
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
  [  {:tzdata, "~> 0.5.3"},  ]
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
