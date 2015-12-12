defmodule Tzdata do
#  alias Tzdata.BasicData, as: TzData
#  alias Tzdata.Periods
#  alias Tzdata.ReleaseParser, as: TzReleaseParser
#  alias Tzdata.LeapSecParser
#
#  @moduledoc """
#  The Tzdata module provides data from the IANA tz database. Also known
#  as the Olson/Eggert database, zoneinfo, tzdata and other names.
#
#  The database files from IANA are text files. Tzdata ships with a copy
#  of the newest files. The `dl_latest_data.sh` script downloads the newest
#  files. When a new version of the database is released from IANA you can
#  run that script and recompile this library. Then the library will use the
#  newest version of the database.
#
#  Or you can get an updated version of this `tzdata`
#  Elixir library where the updated database is included.
#
#  A list of time zone names (e.g. `America/Los_Angeles`) are provided.
#  As well as functions for finding out the UTC offset, abbreviation,
#  standard offset (DST) for a specific point in time in a certain
#  timezone.-dev
#
#  There are also functions for leap seconds. In the `Tzdata.TableData`
#  module, data from the table that matches countries with time zones is
#  available.
#  """
#
#  # Provide lists of zone- and link-names
#  # Note that the function names are different from TzData!
#  # The term "alias" is used instead of "link"
  @doc """
  zone_list provides a list of all the zone names that can be used with
  DateTime. This includes aliases.
  """
  def zone_list, do: Tzdata.ReleaseReader.zone_and_link_list

  @doc """
  Like zone_list, but excludes aliases for zones.
  """
  def canonical_zone_list, do: Tzdata.ReleaseReader.zone_list
#
  @doc """
  A list of aliases for zone names. For instance Europe/Jersey
  is an alias for Europe/London. Aliases are also known as linked zones.
  """

  def zone_alias_list, do: Tzdata.ReleaseReader.link_list

  @doc """
  Takes the name of a zone. Returns true if zone exists. Otherwise false.

      iex> Tzdata.zone_exists? "Pacific/Auckland"
      true
      iex> Tzdata.zone_exists? "America/Sao_Paulo"
      true
      iex> Tzdata.zone_exists? "Europe/Jersey"
      true
  """
  def zone_exists?(name), do: Enum.member?(zone_list, name)
#
  @doc """
  Takes the name of a zone. Returns true if zone exists and is canonical.
  Otherwise false.

      iex> Tzdata.canonical_zone? "Europe/London"
      true
      iex> Tzdata.canonical_zone? "Europe/Jersey"
      false
  """
  def canonical_zone?(name), do: Enum.member?(canonical_zone_list, name)
#
  @doc """
  Takes the name of a zone. Returns true if zone exists and is an alias.
  Otherwise false.

      iex> Tzdata.zone_alias? "Europe/Jersey"
      true
      iex> Tzdata.zone_alias? "Europe/London"
      false
  """
  def zone_alias?(name), do: Enum.member?(zone_alias_list, name)

  @doc """
  Returns a map of links. Also known as aliases.

      iex> Tzdata.links["Europe/Jersey"]
      "Europe/London"
  """
  def links, do: Tzdata.ReleaseReader.links

  @doc """
  Returns a map with keys being group names and the values lists of
  time zone names. The group names mirror the file names used by the tzinfo
  database.
  """
  def zone_lists_grouped, do: Tzdata.ReleaseReader.by_group

  @doc """
  Returns tzdata release version as a string.

  Example:

      Tzdata.tzdata_version
      "2014i"
  """
  def tzdata_version, do: Tzdata.ReleaseReader.release_version

  @doc """
  Returns a list of periods for the `zone_name` provided as an argument.

  A period in this case is a period of time where the UTC offset and standard
  offset are in a certain way. When they change, for instance in spring when
  DST takes effect, a new period starts. For instance a period can begin in
  spring when winter time ends and summer time begins. The period lasts until
  DST ends.

  If either the UTC or standard offset change for any reason, a new period
  begins. For instance instead of DST ending or beginning, a rule change
  that changes the UTC offset will also mean a new period.

  The result is tagged with :ok if the zone_name is correct.

  The from and until times can be :mix, :max or gregorian seconds.

  ## Example

      iex> Tzdata.periods("Europe/Madrid") |> elem(1) |> Enum.take(1)
      [%{from: %{standard: :min, utc: :min, wall: :min}, std_off: 0,
        until: %{standard: 59989766400, utc: 59989767284, wall: 59989766400},
        utc_off: -884, zone_abbr: "LMT"}]
      iex> Tzdata.periods("Not existing")
      {:error, :not_found}
  """
  def periods(zone_name) do
    {tag, p} = Tzdata.ReleaseReader.periods_for_zone_or_link(zone_name)
    case tag do
      :ok ->
        mapped_p = p |> Enum.map(fn {_, f_utc, f_wall, f_std, u_utc, u_wall, u_std, utc_off, std_off, zone_abbr}->
          %{
            std_off: std_off,
            utc_off: utc_off,
            from: %{utc: f_utc, wall: f_wall, standard: f_std},
            until: %{utc: u_utc, standard: u_std, wall: u_wall},
            zone_abbr: zone_abbr
          }
          end)
        {:ok, mapped_p}
      _ -> {:error, p}
    end
  end
#
#  @min_cache_time_point :calendar.datetime_to_gregorian_seconds {{2014, 1, 1}, {0, 0, 0}} # 2014
#  @max_cache_time_point :calendar.datetime_to_gregorian_seconds {{(:calendar.universal_time|>elem(0)|>elem(0)) + 10, 1, 1}, {0, 0, 0}} # 10 years from compile time
#  @wall_time_cache_buffer 3600*24*3 # seconds to stay away from period limits in wall time to avoid problems with overlapping periods
  @doc """
  Get the periods that cover a certain point in time. Usually it will be a list
  with just one period. But in some cases it will be zero or two periods. For
  instance when going from summer to winter time (DST to standard time) there
  will be an overlap if `time_type` is `:wall`.

  `zone_name` should be a valid time zone name. The function `zone_list/0`
  provides a valid list of valid zone names.

  `time_point` is the point in time in gregorian seconds (see erlang
  calendar module documentation for more info on gregorian seconds).

  Valid values for `time_type` is `:utc`, `:wall` or `:standard`.

  ## Examples

      # 63555753600 seconds is equivalent to {{2015, 1, 1}, {0, 0, 0}}
      iex> Tzdata.periods_for_time("Asia/Tokyo", 63587289600, :wall)
      [%{from: %{standard: 61589206800, utc: 61589174400, wall: 61589206800}, std_off: 0,
        until: %{standard: :max, utc: :max, wall: :max}, utc_off: 32400, zone_abbr: "JST"}]

      # 63612960000 seconds is equivalent to 2015-10-25 02:40:00 and is an ambiguous
      # wall time for the zone. So two possible periods will be returned.
      iex> Tzdata.periods_for_time("Europe/Copenhagen", 63612960000, :wall)
      [%{from: %{standard: 63594813600, utc: 63594810000, wall: 63594817200}, std_off: 3600,
              until: %{standard: 63612957600, utc: 63612954000, wall: 63612961200}, utc_off: 3600, zone_abbr: "CEST"},
            %{from: %{standard: 63612957600, utc: 63612954000, wall: 63612957600}, std_off: 0,
              until: %{standard: 63626263200, utc: 63626259600, wall: 63626263200}, utc_off: 3600, zone_abbr: "CET"}]

      # 63594816000 seconds is equivalent to 2015-03-29 02:40:00 and is a
      # non-existing wall time for the zone. It is spring and the clock skips that hour.
      iex> Tzdata.periods_for_time("Europe/Copenhagen", 63594816000, :wall)
      []
  """
#  # For certain years we generate functions that pattern match on certain time points
#  # to more quickly return the correct periods for most time points in those years
#  Enum.each TzData.zone_list, fn (zone_name) ->
#    {:ok, periods} = Periods.periods(zone_name)
#    Enum.each periods, fn(period) ->
#      if period.until.utc > @min_cache_time_point && period.from.utc < @max_cache_time_point do
#        def periods_for_time(unquote(zone_name), time_point, :utc) when time_point > unquote(period.from.utc) and time_point < unquote(period.until.utc) do
#          unquote(Macro.escape([period]))
#        end
#        # For the wall time we make sure that the interval is has to match is a bit more
#        # narrow, but using the buffer
#        def periods_for_time(unquote(zone_name), time_point, :wall) when time_point-@wall_time_cache_buffer> unquote(period.from.wall) and time_point+@wall_time_cache_buffer < unquote(period.until.wall) do
#          unquote(Macro.escape([period]))
#        end
#      end
#    end
#  end
#  # For each linked zone, call canonical zone
#  Enum.each TzData.links, fn {alias_name, canonical_name} ->
#    def periods_for_time(unquote(alias_name), time_point, time_type) do
#      periods_for_time(unquote(canonical_name), time_point, time_type)
#    end
#  end
#
  def periods_for_time(zone_name, time_point, time_type) do
    {:ok, periods} = possible_periods_for_zone_and_time(zone_name, time_point)
    periods
    |> consecutive_matching(fn x ->
                     ((Map.get(x.from, time_type) |>smaller_than_or_equals(time_point))
                     && (Map.get(x.until, time_type) |>bigger_than(time_point)))
                   end)
  end

  # Like Enum.filter, but returns the first consecutive result.
  # If we have found consecutive matches we do not need to look at the
  # remaining list.
  defp consecutive_matching(list, fun) do
    do_consecutive_matching(list, fun, [], false)
  end
  defp do_consecutive_matching([], _fun, [], _did_last_match), do: []
  defp do_consecutive_matching([], _fun, matched, _did_last_match), do: matched
  defp do_consecutive_matching(_list, _fun, matched, false) when length(matched) > 0 do
    # If there are matches and previous did not match then the matches are no
    # long consecutive. So we return the result.
    matched |> Enum.reverse
  end
  defp do_consecutive_matching([h|t], fun, matched, _did_last_match) do
    if fun.(h) == true do
      do_consecutive_matching(t, fun, [h|matched], true)
    else
      do_consecutive_matching(t, fun, matched, false)
    end
  end
#
#  # Use dynamic periods for points in time that are about 50 years into the future
#  @years_in_the_future_where_precompiled_periods_are_used 40
#  @point_from_which_to_use_dynamic_periods :calendar.datetime_to_gregorian_seconds {{(:calendar.universal_time|>elem(0)|>elem(0)) + @years_in_the_future_where_precompiled_periods_are_used, 1, 1}, {0, 0, 0}}
#  defp possible_periods_for_zone_and_time(zone_name, time_point) when time_point >= @point_from_which_to_use_dynamic_periods do
#    # If period in 30 years from compile time goes to :max, use normal periods
#    if Tzdata.FarFutureDynamicPeriods.zone_in_30_years_in_eternal_period?(zone_name) do
#      periods(zone_name)
#    # If not, use dynamic periods
#    else
#      Tzdata.FarFutureDynamicPeriods.periods_for_point_in_time(time_point, zone_name)
#    end
#  end
  @point_from_which_to_use_dynamic_periods 64881043200 # 2055 Dec 31
  defp possible_periods_for_zone_and_time(zone_name, time_point) when time_point >= @point_from_which_to_use_dynamic_periods do
    if Tzdata.FarFutureDynamicPeriods.zone_in_30_years_in_eternal_period?(zone_name) do
      periods(zone_name)
    else
      link_status = Tzdata.ReleaseReader.links |> Map.get(zone_name)
      if link_status == nil do
        Tzdata.FarFutureDynamicPeriods.periods_for_point_in_time(time_point, zone_name)
      else
        possible_periods_for_zone_and_time(link_status, time_point)
      end
    end
  end
  defp possible_periods_for_zone_and_time(zone_name, _time_point) do
    periods(zone_name)
  end

  @doc """
  Get a list of maps with known leap seconds and
  the difference between UTC and the TAI in seconds.

  See also `leap_seconds/1`

  ## Example

      iex> Tzdata.leap_seconds_with_tai_diff |> Enum.take(3)
      [%{date_time: {{1971, 12, 31}, {23, 59, 60}}, tai_diff: 10},
       %{date_time: {{1972,  6, 30}, {23, 59, 60}}, tai_diff: 11},
       %{date_time: {{1972, 12, 31}, {23, 59, 60}}, tai_diff: 12}]
  """
  def leap_seconds_with_tai_diff do
    leap_seconds_data = Tzdata.ReleaseReader.leap_sec_data
    leap_seconds_data[:leap_seconds]
  end
#
  @doc """
  Get a list of known leap seconds. The leap seconds are datetime
  tuples representing the extra leap second to be inserted.
  The date-times are in UTC.

  See also `leap_seconds_with_tai_diff/1`

  ## Example

      iex> Tzdata.leap_seconds |> Enum.take(3)
      [{{1971, 12, 31}, {23, 59, 60}},
       {{1972,  6, 30}, {23, 59, 60}},
       {{1972, 12, 31}, {23, 59, 60}}]
  """
  def leap_seconds do
    leap_seconds_data = Tzdata.ReleaseReader.leap_sec_data
    just_leap_seconds = leap_seconds_data[:leap_seconds]
      |> Enum.map(&(Map.get(&1, :date_time)))
    just_leap_seconds
  end

  @doc """
  The time when the leap second information returned from the other leap second
  related function expires. The date-time is in UTC.

  ## Example

      Tzdata.leap_second_data_valid_until
      {{2015, 12, 28}, {0, 0, 0}}
  """
  def leap_second_data_valid_until do
    leap_seconds_data = Tzdata.ReleaseReader.leap_sec_data
    leap_seconds_data[:valid_until]
  end

  defp smaller_than_or_equals(:min, _), do: true
  defp smaller_than_or_equals(first, second), do: first <= second
  defp bigger_than(:max, _), do: true
  defp bigger_than(first, second), do: first > second
end
