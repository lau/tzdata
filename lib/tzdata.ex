defmodule Tzdata do
  alias Tzdata.BasicData, as: TzData
  alias Tzdata.Periods
  alias Tzdata.ReleaseParser, as: TzReleaseParser
  alias Tzdata.LeapSecParser

  # Provide lists of zone- and link-names
  # Note that the function names are different from TzData!
  # The term "alias" is used instead of "link"
  @doc """
  zone_list provides a list of all the zone names that can be used with
  DateTime. This includes aliases.
  """
  def zone_list, do: unquote(Macro.escape(TzData.zone_and_link_list))

  @doc """
  Like zone_list, but excludes aliases for zones.
  """
  def canonical_zone_list, do: unquote(Macro.escape(TzData.zone_list))

  @doc """
  A list of aliases for zone names. For instance Europe/Jersey
  is an alias for Europe/London. Aliases are also known as linked zones.
  """
  def zone_alias_list, do: unquote(Macro.escape(TzData.link_list))

  @doc """
  Takes the name of a zone. Returns true zone exists. Otherwise false.

      iex> Tzdata.zone_exists? "Pacific/Auckland"
      true
      iex> Tzdata.zone_exists? "America/Sao_Paulo"
      true
      iex> Tzdata.zone_exists? "Europe/Jersey"
      true
  """
  def zone_exists?(name), do: Enum.member?(zone_list, name)

  @doc """
  Takes the name of a zone. Returns true if zone exists and is canonical.
  Otherwise false.

      iex> Tzdata.canonical_zone? "Europe/London"
      true
      iex> Tzdata.canonical_zone? "Europe/Jersey"
      false
  """
  def canonical_zone?(name), do: Enum.member?(canonical_zone_list, name)

  @doc """
  Takes the name of a zone. Returns true if zone exists and is an alias.
  Otherwise false.

      iex> Tzdata.zone_alias? "Europe/Jersey"
      true
      iex> Tzdata.zone_alias? "Europe/London"
      false
  """
  def zone_alias?(name), do: Enum.member?(zone_alias_list, name)

  # Provide map of links
  @doc """
  Returns a map of links. Also known as aliases.

      iex> Tzdata.links["Europe/Jersey"]
      "Europe/London"
  """
  def links, do: unquote(Macro.escape(TzData.links))

  @doc """
  Returns a map with keys being group names and the values lists of
  time zone names. The group names mirror the file names used by the tzinfo
  database.
  """
  def zone_lists_grouped, do: unquote(Macro.escape(TzData.zones_and_links_by_groups))

  @doc """
  Returns tzdata release version as a string.

  Example:

      Tzdata.tzdata_version
      "2014i"
  """
  def tzdata_version, do: unquote(Macro.escape(TzReleaseParser.tzdata_version))

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
  """
  def periods(zone_name) do
    Periods.periods(zone_name)
  end

  @min_cache_time_point 63555753600 # 2014
  @max_cache_time_point 64376208000 # 2040
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
  """
  Enum.each TzData.zone_list, fn (zone_name) ->
    {:ok, periods} = Periods.periods(zone_name)
    Enum.each periods, fn(period) ->
      if period.until.utc > @min_cache_time_point && period.from.utc < @max_cache_time_point do
        def periods_for_time(unquote(zone_name), time_point, :utc) when time_point > unquote(period.from.utc) and time_point < unquote(period.until.utc) do
          unquote(Macro.escape([period]))
        end
      end
    end
  end
  # For each linked zone, call canonical zone
  Enum.each TzData.links, fn {alias_name, canonical_name} ->
    def periods_for_time(unquote(alias_name), time_point, :utc) do
      periods_for_time(unquote(canonical_name), time_point, :utc)
    end
  end

  def periods_for_time(zone_name, time_point, time_type) do
    {:ok, periods} = periods(zone_name)
    periods
    |> Enum.filter(fn x ->
                     ((x[:from][time_type] |>smaller_than_or_equals time_point)
                     && (x[:until][time_type] |>bigger_than time_point))
                   end)
  end

  leap_seconds_data = LeapSecParser.read_file
  @doc """
  Get a list of maps with known leap seconds and
  the difference between UTC and the TAI in seconds.

  See also `leap_seconds/1`

  ## Example

      iex> Tzdata.leap_seconds_with_tai_diff |> Enum.take 3
      [%{date_time: {{1971, 12, 31}, {23, 59, 60}}, tai_diff: 10},
       %{date_time: {{1972,  6, 30}, {23, 59, 60}}, tai_diff: 11},
       %{date_time: {{1972, 12, 31}, {23, 59, 60}}, tai_diff: 12}]
  """
  def leap_seconds_with_tai_diff do
    unquote(Macro.escape(leap_seconds_data[:leap_seconds]))
  end

  just_leap_seconds = leap_seconds_data[:leap_seconds]
    |> Enum.map &(&1[:date_time])
  @doc """
  Get a list of known leap seconds. The leap seconds are datetime
  tuples representing the extra leap second to be inserted.
  The date-times are in UTC.

  See also `leap_seconds_with_tai_diff/1`

  ## Example

      iex> Tzdata.leap_seconds |> Enum.take 3
      [{{1971, 12, 31}, {23, 59, 60}},
       {{1972,  6, 30}, {23, 59, 60}},
       {{1972, 12, 31}, {23, 59, 60}}]
  """
  def leap_seconds do
    unquote(Macro.escape(just_leap_seconds))
  end

  @doc """
  The time when the leap second information returned from the other leap second
  related function expires. The date-time is in UTC.

  ## Example

      Tzdata.leap_second_data_valid_until
      {{2015, 12, 28}, {0, 0, 0}}
  """
  def leap_second_data_valid_until do
    unquote(Macro.escape(leap_seconds_data[:valid_until]))
  end

  defp smaller_than_or_equals(:min, _), do: true
  defp smaller_than_or_equals(first, second), do: first <= second
  defp bigger_than(:max, _), do: true
  defp bigger_than(first, second), do: first > second
end
