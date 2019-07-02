defmodule Tzdata.Util do
  @moduledoc false

  @doc """
    Take strings of amounts and convert them to ints of seconds.
    For instance useful for strings from TZ gmt offsets.

    iex> string_amount_to_secs("0")
    0
    iex> string_amount_to_secs("10")
    36000
    iex> string_amount_to_secs("1:00")
    3600
    iex> string_amount_to_secs("-0:01:15")
    -75
    iex> string_amount_to_secs("-2:00")
    -7200
    iex> string_amount_to_secs("-1:30")
    -5400
    iex> string_amount_to_secs("0:50:20")
    3020
  """
  def string_amount_to_secs("0"), do: 0

  def string_amount_to_secs(string) do
    string
    |> String.replace(~r/\s/, "")
    |> String.split(":")
    |> _string_amount_to_secs
  end

  # If there is only one or two elements, add 00 minutes or 00 seconds
  # until we have a 3 element list
  defp _string_amount_to_secs([h]) do
    _string_amount_to_secs([h, "0", "0"])
  end

  defp _string_amount_to_secs([h, m]) do
    _string_amount_to_secs([h, m, "0"])
  end

  # maybe the hours are negative, so multiply the result by -1
  defp _string_amount_to_secs([<<?-::utf8>> <> hours, m, s]) do
    -1 * _string_amount_to_secs([hours, m, s])
  end

  defp _string_amount_to_secs([h, m, s]) do
    {hours, ""} = Integer.parse(h)
    {mins, ""} = Integer.parse(m)
    {secs, ""} = Integer.parse(s)
    hours * 3600 + mins * 60 + secs
  end

  @doc """
  Provide a certain day number (eg. 1 for monday, 2 for tuesday)
  or downcase 3 letter abbreviation eg. "mon" for monday
  and a year and month.
  Get the last day of that type of the specified month.
  Eg 2014, 8, 5 for the last friday of August 2014. Will return 29

    iex> last_weekday_of_month(2014, 8, 5)
    29
  """
  def last_weekday_of_month(year, month, weekday) do
    weekday = weekday_string_to_number!(weekday)
    days_in_month = day_count_for_month(year, month)
    day_list = Enum.to_list(days_in_month..1)
    {:ok, day} = first_matching_weekday_in_month(year, month, weekday, day_list)
    day
  end

  # returns tuple with {year, month, day}
  # e.g. first Sunday of a certain month. But at least on the 25th. Not before.
  # Can be in the next month if no matching date and weekday is found in the specified month
  defp first_weekday_of_month_at_least(year, month, weekday, minimum_date) do
    weekday = weekday_string_to_number!(weekday)
    days_in_month = day_count_for_month(year, month)
    day_list = Enum.to_list(minimum_date..days_in_month)

    case first_matching_weekday_in_month(year, month, weekday, day_list) do
      {:ok, day} when is_integer(day) ->
        {year, month, day}

      {:error, :not_found} ->
        # If not found, go to the next month and find it.
        # Example of where this is needed is Toronto rule for April 1932
        # where Sunday >= 25 in April is used. But the first Sunday on or after April 25 is in May.
        # We want to find May 1st so we advance one month.
        # See https://github.com/eggert/tz/commit/c86b7fb7b09a
        {new_year, new_month} = next_month(year, month)
        first_weekday_of_month_at_least(new_year, new_month, weekday, 1)
    end
  end

  # E.g. First found Sunday of a certain month on the 3rd of the month or earlier in the month.
  # Can be in the previous month if no matching date and weekday is found in the specified month
  defp first_weekday_of_month_at_most(year, month, weekday, maximum_date) do
    weekday = weekday_string_to_number!(weekday)
    day_list = Enum.to_list(maximum_date..1)

    case first_matching_weekday_in_month(year, month, weekday, day_list) do
      {:ok, day} when is_integer(day) ->
        {year, month, day}

      {:error, :not_found} ->
        # If not found, go to the previous month and find it.
        {new_year, new_month} = prev_month(year, month)

        first_weekday_of_month_at_most(
          new_year,
          new_month,
          weekday,
          day_count_for_month(new_year, new_month)
        )
    end
  end

  defp next_month(year, 12) when is_integer(year), do: {year + 1, 1}

  defp next_month(year, month) when is_integer(year) and month <= 11 and month >= 1,
    do: {year, month + 1}

  defp prev_month(year, 1) when is_integer(year), do: {year - 1, 12}

  defp prev_month(year, month) when is_integer(year) and month <= 12 and month >= 2,
    do: {year, month - 1}

  defp first_matching_weekday_in_month(year, month, weekday, [head | tail]) do
    if weekday == day_of_the_week(year, month, head) do
      {:ok, head}
    else
      first_matching_weekday_in_month(year, month, weekday, tail)
    end
  end

  defp first_matching_weekday_in_month(_, _, _, []) do
    {:error, :not_found}
  end

  def day_count_for_month(year, month), do: :calendar.last_day_of_the_month(year, month)

  def day_of_the_week(year, month, day), do: :calendar.day_of_the_week(year, month, day)

  def weekday_string_to_number!("mon"), do: 1
  def weekday_string_to_number!("tue"), do: 2
  def weekday_string_to_number!("wed"), do: 3
  def weekday_string_to_number!("thu"), do: 4
  def weekday_string_to_number!("fri"), do: 5
  def weekday_string_to_number!("sat"), do: 6
  def weekday_string_to_number!("sun"), do: 7
  # pass through if not matched!
  def weekday_string_to_number!(parm), do: parm

  def month_number_for_month_name(string) do
    string
    |> String.downcase()
    |> cap_month_number_for_month_name
  end

  defp cap_month_number_for_month_name("jan"), do: 1
  defp cap_month_number_for_month_name("feb"), do: 2
  defp cap_month_number_for_month_name("mar"), do: 3
  defp cap_month_number_for_month_name("apr"), do: 4
  defp cap_month_number_for_month_name("may"), do: 5
  defp cap_month_number_for_month_name("jun"), do: 6
  defp cap_month_number_for_month_name("jul"), do: 7
  defp cap_month_number_for_month_name("aug"), do: 8
  defp cap_month_number_for_month_name("sep"), do: 9
  defp cap_month_number_for_month_name("oct"), do: 10
  defp cap_month_number_for_month_name("nov"), do: 11
  defp cap_month_number_for_month_name("dec"), do: 12
  defp cap_month_number_for_month_name(string), do: to_int(string)

  @doc false &&
         """
         Takes a year and month int and a day that is a string.
         The day string can be either a number e.g. "5" or TZ data style definition
         such as "lastSun" or sun>=8

           > tz_day_to_date(2000, 4, "lastSun")
           {2000, 4, 30}
           > tz_day_to_date(1932, 4, "Sun>=25")
           {1932, 5, 1}
           > tz_day_to_date(2005, 4, "Fri<=1")
           {2005, 4, 1}
           > tz_day_to_date(2005, 4, "Mon<=1")
           {2005, 3, 28}
         """
  def tz_day_to_date(year, month, day) do
    last_regex = ~r/last(?<day_name>[^\s]+)/
    at_least_regex = ~r/(?<day_name>[^\s]+)\>\=(?<at_least>\d+)/
    at_most_regex = ~r/(?<day_name>[a-zA-Z]+)\<\=(?<at_most>\d+)/

    cond do
      Regex.match?(last_regex, day) ->
        weekdayHash = Regex.named_captures(last_regex, day)
        day_name = String.downcase(weekdayHash["day_name"])
        day = last_weekday_of_month(year, month, day_name)
        {year, month, day}

      Regex.match?(at_least_regex, day) ->
        weekdayHash = Regex.named_captures(at_least_regex, day)
        day_name = String.downcase(weekdayHash["day_name"])
        minimum_date = to_int(weekdayHash["at_least"])
        # At least meaning e.g. at least on the 25th of the month. Or later.
        {year, month, day} = first_weekday_of_month_at_least(year, month, day_name, minimum_date)
        {year, month, day}

      Regex.match?(at_most_regex, day) ->
        weekdayHash = Regex.named_captures(at_most_regex, day)
        day_name = String.downcase(weekdayHash["day_name"])
        maximum_day = to_int(weekdayHash["at_most"])
        # At most meaning e.g. at most on the 5th of the month. Or before.
        {year, month, day} = first_weekday_of_month_at_most(year, month, day_name, maximum_day)
        {year, month, day}

      true ->
        {year, month, to_int(day)}
    end
  end

  def to_int(string) do
    elem(Integer.parse(string), 0)
  end

  def transform_until_datetime(nil), do: nil

  def transform_until_datetime(input_date_string) do
    regex_year_only = ~r/(?<year>\d+)/
    regex_year_month = ~r/(?<year>\d+)[\s]+(?<month>[^\s]+)/
    regex_year_date = ~r/(?<year>\d+)[\s]+(?<month>[^\s]+)[\s]+(?<date>[^\s]*)/

    regex_year_date_time =
      ~r/(?<year>\d+)[\s]+(?<month>[^\s]+)[\s]+(?<date>[^\s]+)[\s]+(?<hour>[^\s]*):(?<min>[^\s]*)/

    cond do
      Regex.match?(regex_year_date_time, input_date_string) ->
        captured = Regex.named_captures(regex_year_date_time, input_date_string)
        transform_until_datetime(:year_date_time, captured)

      Regex.match?(regex_year_date, input_date_string) ->
        captured = Regex.named_captures(regex_year_date, input_date_string)
        transform_until_datetime(:year_date, captured)

      Regex.match?(regex_year_month, input_date_string) ->
        captured = Regex.named_captures(regex_year_month, input_date_string)
        transform_until_datetime(:year_month, captured)

      Regex.match?(regex_year_only, input_date_string) ->
        captured = Regex.named_captures(regex_year_only, input_date_string)
        transform_until_datetime(:year_only, captured)

      true ->
        raise "none matched"
    end
  end

  def transform_until_datetime(:year_date_time, map) do
    year = to_int(map["year"])
    month_number = month_number_for_month_name(map["month"])

    {year_calculated, month_calculated, day_calculated} =
      tz_day_to_date(year, month_number, map["date"])

    {{{year_calculated, month_calculated, day_calculated},
      {to_int(map["hour"]), to_int(map["min"]), 00}}, time_modifier(map["min"])}
  end

  def transform_until_datetime(:year_date, map) do
    year = to_int(map["year"])
    month_number = month_number_for_month_name(map["month"])

    {year_calculated, month_calculated, day_calculated} =
      tz_day_to_date(year, month_number, map["date"])

    {{{year_calculated, month_calculated, day_calculated}, {0, 0, 0}}, :wall}
  end

  def transform_until_datetime(:year_month, map) do
    year = to_int(map["year"])
    month_number = month_number_for_month_name(map["month"])
    {{{year, month_number, 1}, {0, 0, 0}}, :wall}
  end

  def transform_until_datetime(:year_only, map) do
    {{{to_int(map["year"]), 1, 1}, {0, 0, 0}}, :wall}
  end

  @doc """
  Given a string of a Rule "AT" column return a tupple of a erlang style
  time tuple and a modifier that can be either :wall, :standard or :utc

  ## Examples
      iex> transform_rule_at("2:20u")
      {{2,20,0}, :utc}
      iex> transform_rule_at("2:00s")
      {{2,0,0}, :standard}
      iex> transform_rule_at("2:00")
      {{2,0,0}, :wall}
      iex> transform_rule_at("0")
      {{0,0,0}, :wall}
  """
  def transform_rule_at("0"), do: transform_rule_at("0:00")

  def transform_rule_at(string) do
    modifier = string |> time_modifier
    map = Regex.named_captures(~r/(?<hours>[0-9]{1,2})[\:\.](?<minutes>[0-9]{1,2})/, string)
    {{map["hours"] |> to_int, map["minutes"] |> to_int, 0}, modifier}
  end

  @doc """
  Takes a string and returns a time modifier
  if the string contains z u or g it's UTC
  if it contains s it's standard
  otherwise it's walltime

  ## Examples
      iex> time_modifier("10:20u")
      :utc
      iex> time_modifier("10:20")
      :wall
      iex> time_modifier("10:20 S")
      :standard
  """
  def time_modifier(string) do
    string = String.downcase(string)

    cond do
      Regex.match?(~r/[zug]/, string) -> :utc
      Regex.match?(~r/s/, string) -> :standard
      true -> :wall
    end
  end

  @doc """
  Takes rule and year and returns true or false depending on whether
  the rule applies for the year.

  ## Examples
      iex> rule_applies_for_year(%{at: "23:00", from: 1916, in: 5, letter: "S", name: "Denmark", on: "14", record_type: :rule, save: 3600, to: :only, type: "-"}, 1916)
      true
      iex> rule_applies_for_year(%{at: "23:00", from: 1916, in: 5, letter: "S", name: "Denmark", on: "14", record_type: :rule, save: "1:00", to: :only, type: "-"}, 2000)
      false
      iex> rule_applies_for_year(%{at: "2:00", from: 1993, in: "Oct", letter: "S", name: "Thule", on: "lastSun", record_type: :rule, save: "0", to: 2006, type: "-"}, 1993)
      true
      iex> rule_applies_for_year(%{at: "2:00", from: 1994, in: "Oct", letter: "S", name: "Thule", on: "lastSun", record_type: :rule, save: "0", to: 2006, type: "-"}, 1994)
      true
      iex> rule_applies_for_year(%{at: "2:00", from: 1994, in: "Oct", letter: "S", name: "Thule", on: "lastSun", record_type: :rule, save: "0", to: 2006, type: "-"}, 2006)
      true
      iex> rule_applies_for_year(%{at: "2:00", from: 1994, in: "Oct", letter: "S", name: "Thule", on: "lastSun", record_type: :rule, save: "0", to: 2006, type: "-"}, 2007)
      false
      iex> rule_applies_for_year(%{at: "1:00u", from: 1981, in: "Mar", letter: "S", name: "EU", on: "lastSun", record_type: :rule, save: "1:00", to: :max, type: "-"}, 2014)
      true
      iex> rule_applies_for_year(%{at: "1:00u", from: 1981, in: "Mar", letter: "S", name: "EU", on: "lastSun", record_type: :rule, save: "1:00", to: :max, type: "-"}, 1981)
      true
      iex> rule_applies_for_year(%{at: "1:00u", from: 1981, in: "Mar", letter: "S", name: "EU", on: "lastSun", record_type: :rule, save: "1:00", to: :max, type: "-"}, 1980)
      false
  """
  def rule_applies_for_year(rule, year) do
    rule_applies_for_year_h(rule.from, rule.to, year)
  end

  defp rule_applies_for_year_h(rule_from, :only, year) do
    rule_from == year
  end

  defp rule_applies_for_year_h(rule_from, :max, year) do
    year >= rule_from
  end

  # if we have reached this point, we assume "to" is a year number and
  # convert to integer
  defp rule_applies_for_year_h(rule_from, rule_to, year) do
    rule_applies_for_year_ints(rule_from, rule_to, year)
  end

  defp rule_applies_for_year_ints(rule_from, rule_to, year)
       when rule_from > year or rule_to < year do
    false
  end

  defp rule_applies_for_year_ints(_, _, _) do
    true
  end

  @doc """
  Returns true if the rule applies after the given year.

  Useful for filtering out rules which are no longer valid when building periods.

  ## Examples
      iex> rule_applies_after_year?(%{at: "23:00", from: 1916, in: 5, letter: "S", name: "Denmark", on: "14", record_type: :rule, save: 3600, to: :only, type: "-"}, 1915)
      true
      iex> rule_applies_after_year?(%{at: "23:00", from: 1916, in: 5, letter: "S", name: "Denmark", on: "14", record_type: :rule, save: "1:00", to: :only, type: "-"}, 2000)
      false
      iex> rule_applies_after_year?(%{at: "2:00", from: 1993, in: "Oct", letter: "S", name: "Thule", on: "lastSun", record_type: :rule, save: "0", to: 2006, type: "-"}, 1992)
      true
      iex> rule_applies_after_year?(%{at: "2:00", from: 1994, in: "Oct", letter: "S", name: "Thule", on: "lastSun", record_type: :rule, save: "0", to: 2006, type: "-"}, 1994)
      true
      iex> rule_applies_after_year?(%{at: "2:00", from: 1994, in: "Oct", letter: "S", name: "Thule", on: "lastSun", record_type: :rule, save: "0", to: 2006, type: "-"}, 2006)
      true
      iex> rule_applies_after_year?(%{at: "2:00", from: 1994, in: "Oct", letter: "S", name: "Thule", on: "lastSun", record_type: :rule, save: "0", to: 2006, type: "-"}, 2007)
      false
      iex> rule_applies_after_year?(%{at: "1:00u", from: 1981, in: "Mar", letter: "S", name: "EU", on: "lastSun", record_type: :rule, save: "1:00", to: :max, type: "-"}, 2014)
      true
      iex> rule_applies_after_year?(%{at: "1:00u", from: 1981, in: "Mar", letter: "S", name: "EU", on: "lastSun", record_type: :rule, save: "1:00", to: :max, type: "-"}, 1981)
      true
      iex> rule_applies_after_year?(%{at: "1:00u", from: 1981, in: "Mar", letter: "S", name: "EU", on: "lastSun", record_type: :rule, save: "1:00", to: :max, type: "-"}, 1980)
      true
  """
  def rule_applies_after_year?(rule, year) do
    case rule.to do
      :only ->
        rule.from >= year

      :max ->
        true

      to ->
        to >= year
    end
  end

  @doc """
  Takes a list of rules and a year.
  Returns the same list of rules except the rules that do not apply
  for the year.
  """
  def rules_for_year(rules, year) do
    rules |> Enum.filter(fn rule -> rule_applies_for_year(rule, year) end)
  end

  @doc """
  Takes a rule and a year.
  Returns the date and time of when the rule goes into effect.
  """
  def time_for_rule(rule, year) do
    {time, modifier} = rule.at
    month = rule.in
    {year_calculated, month_calculated, day_calculated} = tz_day_to_date(year, month, rule.on)
    {{{year_calculated, month_calculated, day_calculated}, time}, modifier}
  end

  @doc "Converts a datetime and a type (:utc | :standard | wall) to a number of gregorian seconds"
  def datetime_to_utc({datetime, :utc}, _, _) when is_tuple(datetime) do
    :calendar.datetime_to_gregorian_seconds(datetime)
  end

  def datetime_to_utc({datetime, :standard}, utc_off, _) when is_tuple(datetime) do
    :calendar.datetime_to_gregorian_seconds(datetime) - utc_off
  end

  def datetime_to_utc({datetime, :wall}, utc_off, std_off) when is_tuple(datetime) do
    :calendar.datetime_to_gregorian_seconds(datetime) - utc_off - std_off
  end

  def datetime_to_utc(datetime, _, _) when datetime in [:min, :max] do
    datetime
  end

  @doc """
  Takes a zone abbreviation, a standard offset integer
  and a "letter" as found in a the letter column of a tz rule.
  Depending on whether the standard offset is 0 or not, an suitable
  abbreviation will be returned.

  ## Examples
      iex> period_abbrevation("CE%sT", 0, "-")
      "CET"
      iex> period_abbrevation("CE%sT", 3600, "S")
      "CEST"
      iex> period_abbrevation("GMT/BST", 0, "-")
      "GMT"
      iex> period_abbrevation("GMT/BST", 3600, "S")
      "BST"
  """
  def period_abbrevation(zone_abbr, std_off, letter) do
    if Regex.match?(~r/\//, zone_abbr) do
      period_abbrevation_h(:slash, zone_abbr, std_off, letter)
    else
      period_abbrevation_h(:no_slash, zone_abbr, std_off, letter)
    end
  end

  defp period_abbrevation_h(:slash, zone_abbr, 0, _) do
    map = Regex.named_captures(~r/(?<first>[^\/]+)\/(?<second>[^\/]+)/, zone_abbr)
    map["first"]
  end

  defp period_abbrevation_h(:slash, zone_abbr, _, _) do
    map = Regex.named_captures(~r/(?<first>[^\/]+)\/(?<second>[^\/]+)/, zone_abbr)
    map["second"]
  end

  defp period_abbrevation_h(:no_slash, zone_abbr, _, "-") do
    String.replace(zone_abbr, "%s", "")
  end

  defp period_abbrevation_h(:no_slash, zone_abbr, _, letter) when is_binary(letter) do
    String.replace(zone_abbr, "%s", letter)
  end

  defp period_abbrevation_h(:no_slash, zone_abbr, _, :undefined) do
    zone_abbr
  end

  def strip_comment(line), do: Regex.replace(~r/[\s]*#.+/, line, "")

  def filter_comment_lines(input) do
    Stream.filter(input, fn x -> !Regex.match?(~r/^[\s]*#/, x) end)
  end

  def filter_empty_lines(input) do
    Stream.filter(input, fn x -> !Regex.match?(~r/^\n$/, x) end)
  end

  def data_dir do
    case Application.fetch_env(:tzdata, :data_dir) do
      {:ok, nil} -> Application.app_dir(:tzdata, "priv")
      {:ok, dir} -> dir
      _ -> Application.app_dir(:tzdata, "priv")
    end
  end

  def custom_data_dir_configured? do
    case Application.fetch_env(:tzdata, :data_dir) do
      {:ok, nil} -> false
      {:ok, _dir} -> true
      _ -> false
    end
  end
end
