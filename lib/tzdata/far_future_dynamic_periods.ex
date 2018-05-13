defmodule Tzdata.FarFutureDynamicPeriods do
  # This module is for calculating periods far into the future
  # for time zones with DST. It is assumed that there are two
  # rules per year: one for going off of DST and one for going on DST.
  #
  # Instead of caching 10000 years worth of periods, we can use this
  # module for periods that are far into the feature and only
  # cache periods that are close to compile time.

  @moduledoc false
  alias Tzdata.ReleaseReader
  alias Tzdata.Util

  # February 1st 30 years from compile time
  @greg_sec_30_years_from_now :calendar.datetime_to_gregorian_seconds {{(:calendar.universal_time|>elem(0)|>elem(0)) + 30, 2, 1}, {0, 0, 0}}

  # 30 years from compile time, is the zone in a period
  # that runs until :max ? Ie. it is not using DST
  # If it is not using DST the last cached period is valid forever
  # and we do not want to use this module for that timezone.
  def zone_in_30_years_in_eternal_period?(zone_name) do
    y=Tzdata.periods_for_time(zone_name, @greg_sec_30_years_from_now, :utc) |> hd
    y.until.utc == :max
  end

  def periods_for_point_in_time({{year, _month, _day}, _}, zone_name) do
    fp_data = first_period_that_ends_in_year(zone_name, year)
    first_period = fp_data.period
    # We repeat the rules 3 times which is enough for the 4 periods we need
    rules = fp_data.rules ++ fp_data.rules ++ fp_data.rules
    rules_per_year = length(fp_data.rules)
     if rules_per_year != 2 do
       raise "dynamic periods assume 2 rules per year"
     end
    {:ok, periods_until_year([first_period], first_period.until.utc, first_period.utc_off, fp_data.zone_line, rules, year, rules_per_year)
    }
  end
  # If datetime is not provided in erlang tuple, assume it is gregorian seconds
  # and convert and send along.
  def periods_for_point_in_time(gregorian_seconds, zone_name) do
    periods_for_point_in_time(gregorian_seconds|>:calendar.gregorian_seconds_to_datetime, zone_name)
  end

  defp periods_until_year(prev_periods, from, utc_off, zone_line, rules, year, rules_per_year) do
    begin_rule = rules |> hd
    end_rule = rules |> tl |> hd
    std_off = begin_rule.save

    until_time_year = case length(prev_periods) >= rules_per_year do
      true -> year + 1
      false -> year
    end

    from_standard_time = standard_time_from_utc(from, utc_off)
    from_wall_time = wall_time_from_utc(from, utc_off, std_off)
    until_utc = Util.datetime_to_utc(Util.time_for_rule(end_rule, until_time_year), utc_off, std_off)
    until_standard_time = standard_time_from_utc(until_utc, utc_off)
    until_wall_time = wall_time_from_utc(until_utc, utc_off, std_off)

    period = %{
      std_off: std_off,
      utc_off: utc_off,
      from: %{utc: from, wall: from_wall_time, standard: from_standard_time},
      until: %{standard: until_standard_time, wall: until_wall_time, utc: until_utc},
      zone_abbr: Util.period_abbrevation(zone_line.format, std_off, begin_rule.letter)
    }

    {{until_year_wall, _, _}, _} = :calendar.gregorian_seconds_to_datetime(until_wall_time)

    if length(prev_periods) == rules_per_year do
       prev_periods ++ [period]
    else
       periods_until_year(prev_periods ++ [period], until_utc, utc_off, zone_line, rules |> tl, until_year_wall, rules_per_year)
    end
  end

  defp first_period_that_ends_in_year(zone_name, year) do
    zone_line = last_line_for_zone(zone_name)
    {:named_rules, rule_name} = zone_line.rules
    rules = rules_applying_for_rule_name_and_year(rule_name, year)
    utc_off = zone_line.gmtoff

    rule_beginning_of_year = Enum.reverse(rules) |> tl |> hd
    rule_end_of_year = Enum.reverse(rules) |> hd

    # std off before is the offset before the first period starts
    std_off_before = rule_beginning_of_year.save
    std_off = rule_end_of_year.save
    from = Util.datetime_to_utc(Util.time_for_rule(rule_end_of_year, year-1), utc_off, std_off_before)
    letter = rule_end_of_year.letter

    from_standard_time = standard_time_from_utc(from, utc_off)
    from_wall_time = wall_time_from_utc(from, utc_off, std_off)
    until_utc = Util.datetime_to_utc(Util.time_for_rule(rule_beginning_of_year, year), utc_off, std_off)
    until_standard_time = standard_time_from_utc(until_utc, utc_off)
    until_wall_time = wall_time_from_utc(until_utc, utc_off, std_off)

    period = %{
      std_off: std_off,
      utc_off: utc_off,
      from: %{utc: from, wall: from_wall_time, standard: from_standard_time},
      until: %{standard: until_standard_time, wall: until_wall_time, utc: until_utc},
      zone_abbr: Util.period_abbrevation(zone_line.format, std_off, letter)
    }
    %{period: period, rules: rules, zone_line: zone_line, rule_name: rule_name}
  end

  defp last_line_for_zone(zone_name) do
    {:ok, z}=ReleaseReader.zone(zone_name)
    last_line = z.zone_lines |> Enum.reverse |> hd
    last_line
  end

  defp rules_applying_for_rule_name_and_year(rule_name, year) do
    {:ok, rules} = ReleaseReader.rules_for_name(rule_name)
    rules
    |> Util.rules_for_year(year)
    |> Enum.sort(&(&1.in < &2.in))
  end

  def standard_time_from_utc(atom, _) when is_atom(atom), do: atom
  def standard_time_from_utc(utc_time, utc_off) do
    utc_time + utc_off
  end

  def wall_time_from_utc(atom, _, _) when is_atom(atom), do: atom
  def wall_time_from_utc(utc_time, utc_offset, standard_offset) do
    utc_time + utc_offset + standard_offset
  end
end
