Tzdata
======

[![Build
Status](https://travis-ci.org/lau/tzdata.svg?branch=master)](https://travis-ci.org/lau/tzdata)

Tzdata. The [timezone database](https://www.iana.org/time-zones) in Elixir.

Extracted from the [Calendar](https://github.com/lau/calendar) library.

As of version 0.1.6 the tz release 2015e (from 2015-06-13 10:56:02 -0700)
is used. The tz release version can be verified with the following function:

```elixir
iex> Tzdata.tzdata_version
"2015e"
```

## Getting started

Use through the [Calendar](https://github.com/lau/calendar) library
or directly: it is available on hex as `tzdata`.

```elixir
defp deps do
  [  {:tzdata, "~> 0.1.7"},  ]
end
```

## Documentation

Documentation can be found at http://hexdocs.pm/tzdata/

## When new timezone data is released

IANA releases new versions of the [timezone database](https://www.iana.org/time-zones) frequently. When that
happens, hopefully this library will be updated within 24 hours with the new
data and a new version of the tzdata Elixir package will be released.

As an alternative to getting a new version of tzdata, users of this library
can simply run the `dl_latest_data.sh` script and then recompile tzdata. Running
that script will update the data in the `source_data` directory. The files in the
`source_data` directory contains all the information about the timezones
and is used by the tzdata library at compile time.

## License

The tzdata Elixir library is released under the MIT license. See the LICENSE file.

The tz database files (found in the source_data directory) is public domain.

## tzdata, escript and 0.1.9

**NOTE: 0.1.9 is not an official release. This is a fork from 0.1.8, with a
few fixes to address compilation errors and warnings using Elixir 1.10.**

The reason to support this older version of tzdata is to support escript.

There is a known [issue](https://github.com/bitwalker/timex/issues/86)
with recent (0.5+) versions and using escript. The recommendation is
to use 0.1.8. However, this fails compilation with Elixir 1.10,
example error (left here for SEO reasons)

```
warning: variable "max_year_to_use" does not exist and is being expanded to "max_year_to_use()", please use parentheses to remove the ambiguity or change the variable name
  lib/tzdata/period_builder.ex:60: Tzdata.PeriodBuilder.calc_periods/4

warning: variable "period" is unused (if the variable is not meant to be used, prefix it with an underscore)
  lib/tzdata/period_builder.ex:171: Tzdata.PeriodBuilder.calc_periods_for_year/8

warning: undefined function max_year_to_use/0
  lib/tzdata/period_builder.ex:60


== Compilation error in file lib/tzdata/period_builder.ex ==
** (CompileError) lib/tzdata/period_builder.ex:60: undefined function from_standard_time_year/0
    (elixir 1.10.0) src/elixir_locals.erl:114: anonymous fn/3 in :elixir_locals.ensure_no_undefined_local/3
    (stdlib 3.11.1) erl_eval.erl:680: :erl_eval.do_apply/6
```

This fork fixes these and other issues. Unit-tests still pass;

```
$ mix test
Compiling 10 files (.ex)
Compiling lib/tzdata.ex (it's taking more than 15s)
..................................................

Finished in 0.3 seconds
16 doctests, 34 tests, 0 failures
```