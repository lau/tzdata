defmodule Tzdata.PeriodBuilder do
  @moduledoc false

  alias Tzdata.Util, as: TzUtil
  # the first year to use when looking at rules
  @min_year 1900
  # the last year to use when looking at rules
  @years_in_the_future_where_precompiled_periods_are_used 40
  @extra_years_to_precompile 4
  @max_year (:calendar.universal_time() |> elem(0) |> elem(0)) +
              @years_in_the_future_where_precompiled_periods_are_used + @extra_years_to_precompile

  def calc_periods(btz_data, zone_name) do
    {:ok, zone} = zone(btz_data, zone_name)
    calc_periods(btz_data, zone.zone_lines, :min, Map.get(hd(zone.zone_lines), :rules), "")
  end

  defp zone(btz_data, zone_name) do
    {:ok, Map.get(btz_data.zones, zone_name)}
  end

  defp get_rules(btz_data, rules_name) do
    {:ok, Map.get(btz_data.rules, rules_name)}
  end

  def calc_periods(btz_data, [zone_line_hd | zone_line_tl], from, zone_hd_rules, letter)
      when zone_hd_rules == nil do
    # since there are no rules, there is no standard offset
    std_off = 0
    utc_off = zone_line_hd.gmtoff
    from_standard_time = standard_time_from_utc(from, utc_off)
    from_wall_time = wall_time_from_utc(from, utc_off, std_off)
    until_utc = datetime_to_utc(Map.get(zone_line_hd, :until), utc_off, std_off)
    until_standard_time = standard_time_from_utc(until_utc, utc_off)
    until_wall_time = wall_time_from_utc(until_utc, utc_off, std_off)

    period = %{
      std_off: 0,
      utc_off: utc_off,
      from: %{utc: from, wall: from_wall_time, standard: from_standard_time},
      until: %{standard: until_standard_time, wall: until_wall_time, utc: until_utc},
      zone_abbr: zone_line_hd.format
    }

    h_calc_next_zone_line(btz_data, period, until_utc, zone_line_tl, letter)
  end

  def calc_periods(btz_data, [zone_line_hd | zone_line_tl], from, zone_hd_rules, letter) do
    # we start out by assuming there is no offset. the rules might change this
    std_off = 0
    utc_off = zone_line_hd.gmtoff
    from_standard_time = standard_time_from_utc(from, utc_off)
    zone_line_limit = Map.get(zone_line_hd, :until)

    # Get the year of the "from" time. We use the standard time with utc offset
    # applied. If for instance we are ahead of UTC and the period starts at the
    # start of a new year we want the new year.

    from_standard_time_year =
      case from do
        :min ->
          @min_year

        _ ->
          {{year, _, _}, _} = :calendar.gregorian_seconds_to_datetime(from_standard_time)
          year
      end

    max_year_to_use =
      case zone_line_limit do
        {{{year, _, _}, _}, _} -> year
        nil -> @max_year
      end

    years_to_use = from_standard_time_year..max_year_to_use |> Enum.to_list()
    # get rules
    {rules_type, rules_value} = zone_hd_rules

    calc_rule_periods_h(
      btz_data,
      rules_type,
      rules_value,
      [zone_line_hd | zone_line_tl],
      from,
      utc_off,
      std_off,
      years_to_use,
      letter
    )
  end

  # Helper function for function calc_periods with no rules
  # When the zone line tail is empty we are at the last zone line.
  # As this should only be called when there are no rules, we assume that
  # there the period is until :max and thus it is the last period. So we don't
  # add any more periods.
  def h_calc_next_zone_line(_btz_data, period, _, zone_line_tl, _) when zone_line_tl == [] do
    case period do
      nil -> []
      _ -> [ period ]
    end
  end

  # If there is a zone line tail, we recursively add to the list of periods with that zone line tail
  def h_calc_next_zone_line(btz_data, period, until_utc, zone_line_tl, letter) do
    tail = calc_periods(btz_data, zone_line_tl, until_utc, hd(zone_line_tl).rules, letter)
    case period do
      nil -> tail
      _ -> [ period | tail ]
    end
  end

  defp calc_rule_periods_h(
         btz_data,
         :amount,
         rules_value,
         [zone_line_hd | zone_line_tl],
         from,
         _,
         _,
         _,
         letter
       ) do
    std_off = rules_value
    utc_off = Map.get(zone_line_hd, :gmtoff)
    from_standard_time = standard_time_from_utc(from, utc_off)
    from_wall_time = wall_time_from_utc(from, utc_off, std_off)
    until_utc = datetime_to_utc(Map.get(zone_line_hd, :until), utc_off, std_off)
    until_standard_time = standard_time_from_utc(until_utc, utc_off)
    until_wall_time = wall_time_from_utc(until_utc, utc_off, std_off)

    period = %{
      std_off: rules_value,
      utc_off: utc_off,
      from: %{utc: from, wall: from_wall_time, standard: from_standard_time},
      until: %{standard: until_standard_time, wall: until_wall_time, utc: until_utc},
      zone_abbr: zone_line_hd.format
    }

    h_calc_next_zone_line(btz_data, period, until_utc, zone_line_tl, letter)
  end

  defp calc_rule_periods_h(
         btz_data,
         :named_rules,
         rules_value,
         [zone_line_hd | zone_line_tl],
         from,
         utc_off,
         std_off,
         years_to_use,
         letter
       ) do
    {:ok, rules} = get_rules(btz_data, rules_value)

    calc_rule_periods(
      btz_data,
      [zone_line_hd | zone_line_tl],
      from,
      utc_off,
      std_off,
      years_to_use,
      rules,
      letter
    )
  end

  # At the last zone line, which should last until "max".
  # An example of this is Asia/Tokyo where at the time this is written
  # the current period starts in 1951 and is still in effect.
  def calc_rule_periods(_btz_data, [zone_line], from, utc_off, std_off, [], _, letter) do
    from_standard_time = standard_time_from_utc(from, utc_off)
    from_wall_time = wall_time_from_utc(from, utc_off, std_off)

    period = %{
      std_off: std_off,
      utc_off: utc_off,
      from: %{utc: from, wall: from_wall_time, standard: from_standard_time},
      until: %{standard: :max, wall: :max, utc: :max},
      zone_abbr: TzUtil.period_abbrevation(zone_line.format, std_off, letter)
    }

    [period]
  end

  def calc_rule_periods(
        btz_data,
        [zone_line | zone_line_tl],
        from,
        utc_off,
        std_off,
        [],
        _,
        letter
      ) do
    until_utc = datetime_to_utc(Map.get(zone_line, :until), utc_off, std_off)
    tail = calc_periods(btz_data, zone_line_tl, until_utc, Map.get(hd(zone_line_tl), :rules), letter)
    if from == until_utc do # empty period may happen when 'until' of zone line coincides with end of rule
      tail
    else
      from_standard_time = standard_time_from_utc(from, utc_off)
      from_wall_time = wall_time_from_utc(from, utc_off, std_off)
      until_standard_time = standard_time_from_utc(until_utc, utc_off)
      until_wall_time = wall_time_from_utc(until_utc, utc_off, std_off)

      period = %{
        std_off: std_off,
        utc_off: utc_off,
        from: %{utc: from, wall: from_wall_time, standard: from_standard_time},
        until: %{standard: until_standard_time, wall: until_wall_time, utc: until_utc},
        zone_abbr: TzUtil.period_abbrevation(zone_line.format, std_off, letter)
      }

      [ period | tail ]
    end
  end

  def calc_rule_periods(
        btz_data,
        zone_lines,
        from,
        utc_off,
        std_off,
        [years_hd | years_tl],
        zone_rules,
        letter
      ) do
    rules_for_year = TzUtil.rules_for_year(zone_rules, years_hd) |> sort_rules_by_time(years_hd)
    # if there are no rules for the given year, continue with the remaining years
    if rules_for_year == [] do
      calc_rule_periods(
        btz_data,
        zone_lines,
        from,
        utc_off,
        std_off,
        years_tl,
        zone_rules,
        letter
      )
    else
      calc_periods_for_year(
        btz_data,
        zone_lines,
        from,
        utc_off,
        std_off,
        [years_hd | years_tl],
        zone_rules,
        rules_for_year,
        letter,
        from
      )
    end
  end

  def calc_periods_for_year(
        btz_data,
        [zone_line | zone_line_tl],
        from,
        utc_off,
        std_off,
        years,
        zone_rules,
        rules_for_year,
        letter,
        lower_limit
      ) do
    year = years |> hd
    rule = rules_for_year |> hd
    rules_tail = rules_for_year |> tl

    upper_limit = datetime_to_utc(Map.get(zone_line, :until), utc_off, std_off)
    # `from` is inferred from the end of the last period, the `upper_limit` can go back in time in
    # edge cases where the `std_off` has a negative delta and the `until` of the zone line occurs
    # in a time <= delta
    upper_limit_before_from = is_integer(from) && is_integer(upper_limit) && from > upper_limit
    upper_limit = if upper_limit_before_from, do: from, else: upper_limit

    # truncate start of period to within time range of zone line
    from_before_lower_limit = is_integer(lower_limit) && (from == :min || lower_limit > from)
    from = if from_before_lower_limit, do: lower_limit, else: from
    # derive standard and wall time for 'from'
    from_standard_time = standard_time_from_utc(from, utc_off)
    from_wall_time = wall_time_from_utc(from, utc_off, std_off)

    until_utc = datetime_to_utc(TzUtil.time_for_rule(rule, year), utc_off, std_off)
    # truncate end of period to within time range of zone line
    until_before_lower_limit = is_integer(lower_limit) && is_integer(until_utc) && lower_limit > until_utc
    until_utc = if until_before_lower_limit, do: lower_limit, else: until_utc
    last_included_rule = is_integer(upper_limit) && is_integer(until_utc) && upper_limit <= until_utc
    until_utc = if last_included_rule, do: upper_limit, else: until_utc
    # derive standard and wall time for 'until'
    until_standard_time = standard_time_from_utc(until_utc, utc_off)
    until_wall_time = wall_time_from_utc(until_utc, utc_off, std_off)

    # Some times this will calculate periods with zero length.
    # Set period to nil if the length is zero (ie. "until" equals "from")
    # Nil values will be filtered by another function
    period =
      if until_utc == from,
        do: nil,
        else: %{
          std_off: std_off,
          utc_off: utc_off,
          from: %{utc: from, wall: from_wall_time, standard: from_standard_time},
          until: %{standard: until_standard_time, wall: until_wall_time, utc: until_utc},
          zone_abbr: TzUtil.period_abbrevation(zone_line.format, std_off, letter)
        }

    no_more_rules = rules_tail == []
    no_more_years = tl(years) == []

    # If we've hit the upper time boundary of this zone line, we do not need to examine any more
    # rules for this rule set OR there are no more years to consider for this rule set
    if last_included_rule || no_more_years && no_more_rules do
      h_calc_next_zone_line(btz_data, period, until_utc, zone_line_tl, letter)
    else
      tail = cond do
        # If there are no more rules for the year, continue with the next year
        no_more_rules ->
          calc_rule_periods(
            btz_data,
            [zone_line | zone_line_tl],
            until_utc,
            utc_off,
            rule.save,
            years |> tl,
            zone_rules,
            rule.letter
          )
        # Else continue with those rules
        true ->
          calc_periods_for_year(
            btz_data,
            [zone_line | zone_line_tl],
            until_utc,
            utc_off,
            rule.save,
            years,
            zone_rules,
            rules_tail,
            rule.letter,
            lower_limit
          )
      end
      if period == nil, do: tail, else: [ period | tail ]
    end
  end

  # earliest rule first
  # sort by month!
  def sort_rules_by_time(rules, year) do
    # n.b., we can have many rules per month - such as time changes for religious festivals
    rules
    |> Enum.map(&({&1, TzUtil.tz_day_to_date(year, &1.in, &1.on)}))
    |> Enum.sort(&(elem(&1, 1) < elem(&2, 1)))
    |> Enum.map(&(elem(&1, 0)))
  end

  @doc """
  Takes a tuple of date time and modifier that can be :utc, :standard or :wall
  UTC offset in seconds and standard offset in seconds.
  Returns UTC time in seconds.
  """
  # special case for datetime provided being nil. we assume it's for
  # use with a timezone line with until being nil
  def datetime_to_utc(until, _, _) when until == nil do
    :max
  end

  def datetime_to_utc({datetime, modifier}, _, _) when modifier == :utc do
    :calendar.datetime_to_gregorian_seconds(datetime)
  end

  def datetime_to_utc({datetime, modifier}, utc_off, _) when modifier == :standard do
    :calendar.datetime_to_gregorian_seconds(datetime) - utc_off
  end

  def datetime_to_utc({datetime, modifier}, utc_off, std_off) when modifier == :wall do
    :calendar.datetime_to_gregorian_seconds(datetime) - utc_off - std_off
  end

  def standard_time_from_utc(:min, _), do: :min
  def standard_time_from_utc(:max, _), do: :max

  def standard_time_from_utc(utc_time, utc_offset) do
    utc_time + utc_offset
  end

  def wall_time_from_utc(:min, _, _), do: :min
  def wall_time_from_utc(:max, _, _), do: :max

  def wall_time_from_utc(utc_time, utc_offset, standard_offset) do
    utc_time + utc_offset + standard_offset
  end
end
