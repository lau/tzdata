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

    btz_data
    |> calc_periods(zone.zone_lines, :min, Map.get(hd(zone.zone_lines), :rules), nil)
    |> merge_redundant_periods()
  end

  # A zone line boundary (or a rule taking effect) doesn't always produce an
  # observable change: e.g. a zone line can switch from a fixed "CST" format
  # to a named rule set formatted as "C%sT" that, at that point in time,
  # isn't observing DST yet and so still resolves to "CST" with the same UTC
  # offset. Adjacent periods that are identical in every way that matters to
  # an observer (abbreviation and offsets) are merged into one, so a period
  # boundary always corresponds to a real, observable transition.
  defp merge_redundant_periods([a, b | rest]) do
    if mergeable?(a, b) do
      merge_redundant_periods([%{a | until: b.until} | rest])
    else
      [a | merge_redundant_periods([b | rest])]
    end
  end

  defp merge_redundant_periods(periods), do: periods

  defp mergeable?(a, b) do
    a.until.utc == b.from.utc and a.zone_abbr == b.zone_abbr and a.std_off == b.std_off and
      a.utc_off == b.utc_off
  end

  defp zone(btz_data, zone_name) do
    {:ok, Map.get(btz_data.zones, zone_name)}
  end

  defp get_rules(btz_data, rules_name) do
    {:ok, Map.get(btz_data.rules, rules_name)}
  end

  def max_year() do
    case Application.fetch_env(:tzdata, :max_year) do
      {:ok, nil} ->
        @max_year

      {:ok, max_year} ->
        if is_valid_max_year?(max_year) do
          max_year
        else
          @max_year
        end

      _ ->
        @max_year
    end
  end

  def min_year() do
    case Application.fetch_env(:tzdata, :min_year) do
      {:ok, nil} ->
        @min_year

      {:ok, min_year} ->
        if is_valid_min_year?(min_year) do
          min_year
        else
          @min_year
        end

      _ ->
        @min_year
    end
  end

  defp is_valid_max_year?(max_year) when is_integer(max_year) do
    # don't allow greater than default max_year
    max_year <= @max_year
  end

  defp is_valid_max_year?(_max_year) do
    false
  end

  defp is_valid_min_year?(min_year) when is_integer(min_year) do
    # don't allow lower than default min_year
    min_year >= @min_year
  end

  defp is_valid_min_year?(_min_year) do
    false
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
      zone_abbr: TzUtil.period_abbrevation(zone_line_hd.format, std_off, utc_off, letter || "")
    }

    # A zone line with no rules always has std_off 0 - it never carries a
    # meaningful "currently in effect" DST letter of its own. Whatever
    # `letter` we received (possibly a real rule's letter, inherited from
    # some earlier, unrelated zone line/rule set) must not be forwarded past
    # this point: the next zone line, if it has its own rule set, needs to
    # resolve its own default rather than inherit a stale one.
    h_calc_next_zone_line(btz_data, period, until_utc, zone_line_tl, nil)
  end

  def calc_periods(btz_data, [zone_line_hd | zone_line_tl], from, zone_hd_rules, letter) do
    # we start out by assuming there is no offset. the rules might change this
    std_off = 0
    utc_off = zone_line_hd.gmtoff
    from_standard_time = standard_time_from_utc(from, utc_off)
    zone_line_limit = Map.get(zone_line_hd, :until)
    min_year = min_year()
    max_year = max_year()

    # Get the year of the "from" time. We use the standard time with utc offset
    # applied. If for instance we are ahead of UTC and the period starts at the
    # start of a new year we want the new year.

    from_standard_time_year =
      case from do
        :min ->
          min_year

        _ ->
          {{year, _, _}, _} = :calendar.gregorian_seconds_to_datetime(from_standard_time)

          if year < min_year do
            min_year
          else
            year
          end
      end

    max_year_to_use =
      case zone_line_limit do
        {{{year, _, _}, _}, _} ->
          if year > max_year do
            max_year
          else
            year
          end

        nil ->
          max_year
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
      _ -> [period]
    end
  end

  # If there is a zone line tail, we recursively add to the list of periods with that zone line tail
  def h_calc_next_zone_line(btz_data, period, until_utc, zone_line_tl, letter) do
    tail = calc_periods(btz_data, zone_line_tl, until_utc, hd(zone_line_tl).rules, letter)

    case period do
      nil -> tail
      _ -> [period | tail]
    end
  end

  # Like h_calc_next_zone_line/5, but for when `rule` already took effect at
  # the exact instant (`until_utc`) the next zone line begins. We seed the
  # next zone line's starting std_off/letter from `rule` (instead of the
  # usual std_off=0, letter=nil).
  #
  # If the next zone line references the very same rule set `rule` came
  # from, `remaining_rules_for_year` (the rules for `coincidence_year` that
  # come chronologically after `rule` - already known to the caller, since
  # it just finished popping rules off that same list) is reused as-is
  # instead of re-deriving "this year's rules" from scratch. Re-deriving
  # from scratch would re-include rules that already fired earlier in
  # `coincidence_year` under the *old* zone line (e.g. an April DST-start
  # rule, when `rule` itself is a later, one-off same-year rule) and apply
  # their save/letter a second time, producing a spurious extra period -
  # exactly the bug this whole fix is for.
  defp h_calc_next_zone_line_with_rule(
         _btz_data,
         _until_utc,
         [],
         _rule,
         _coincidence_year,
         _remaining_rules_for_year
       ) do
    []
  end

  defp h_calc_next_zone_line_with_rule(
         btz_data,
         until_utc,
         [next_zone_line | rest],
         rule,
         coincidence_year,
         remaining_rules_for_year
       ) do
    case Map.get(next_zone_line, :rules) do
      {:named_rules, rules_value} ->
        {:ok, zone_rules} = get_rules(btz_data, rules_value)
        utc_off = next_zone_line.gmtoff

        max_year_to_use =
          case Map.get(next_zone_line, :until) do
            {{{year, _, _}, _}, _} -> year
            nil -> @max_year
          end

        years_to_use = coincidence_year..max_year_to_use |> Enum.to_list()

        same_rule_set = Enum.any?(zone_rules, &(&1.name == rule.name))

        rules_for_first_year =
          if same_rule_set do
            remaining_rules_for_year
          else
            TzUtil.rules_for_year(zone_rules, coincidence_year)
            |> sort_rules_by_time(coincidence_year)
          end

        case rules_for_first_year do
          [] ->
            calc_rule_periods(
              btz_data,
              [next_zone_line | rest],
              until_utc,
              utc_off,
              rule.save,
              tl(years_to_use),
              zone_rules,
              rule.letter
            )

          rules_for_year ->
            calc_periods_for_year(
              btz_data,
              [next_zone_line | rest],
              until_utc,
              utc_off,
              rule.save,
              years_to_use,
              zone_rules,
              rules_for_year,
              rule.letter,
              until_utc
            )
        end

      _ ->
        # The next zone line doesn't reference a named rule set, so there's
        # no candidate rule search to deduplicate against - just hand off
        # normally, seeded with this rule's letter.
        calc_periods(
          btz_data,
          [next_zone_line | rest],
          until_utc,
          Map.get(next_zone_line, :rules),
          rule.letter
        )
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
      zone_abbr: TzUtil.period_abbrevation(zone_line_hd.format, std_off, utc_off, letter || "")
    }

    # As with the no-rules clause above: a fixed-amount zone line has no
    # rule-derived letter of its own, so don't forward a possibly-stale one
    # to the next zone line.
    h_calc_next_zone_line(btz_data, period, until_utc, zone_line_tl, nil)
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
  def calc_rule_periods(_btz_data, [zone_line], from, utc_off, std_off, [], zone_rules, letter) do
    from_standard_time = standard_time_from_utc(from, utc_off)
    from_wall_time = wall_time_from_utc(from, utc_off, std_off)

    period = %{
      std_off: std_off,
      utc_off: utc_off,
      from: %{utc: from, wall: from_wall_time, standard: from_standard_time},
      until: %{standard: :max, wall: :max, utc: :max},
      zone_abbr:
        TzUtil.period_abbrevation(
          zone_line.format,
          std_off,
          utc_off,
          resolve_letter(letter, zone_rules)
        )
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
        zone_rules,
        letter
      ) do
    until_utc = datetime_to_utc(Map.get(zone_line, :until), utc_off, std_off)

    tail =
      calc_periods(btz_data, zone_line_tl, until_utc, Map.get(hd(zone_line_tl), :rules), letter)

    # empty period may happen when 'until' of zone line coincides with end of rule
    if from == until_utc do
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
        zone_abbr:
          TzUtil.period_abbrevation(
            zone_line.format,
            std_off,
            utc_off,
            resolve_letter(letter, zone_rules)
          )
      }

      [period | tail]
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
    until_before_lower_limit =
      is_integer(lower_limit) && is_integer(until_utc) && lower_limit > until_utc

    until_utc = if until_before_lower_limit, do: lower_limit, else: until_utc

    last_included_rule =
      is_integer(upper_limit) && is_integer(until_utc) && upper_limit <= until_utc

    # A rule can take effect at the exact same wall-clock instant the zone
    # line itself ends (e.g. a country redefines its base UTC offset at the
    # same moment a DST rule starts, so the net observed offset doesn't
    # change - see America/Argentina/Buenos_Aires in 1999). When that
    # happens we must hand the rule's effect (save/letter) to the next zone
    # line instead of silently dropping it, or the next zone line will
    # re-derive this same rule's effective time using its own (different)
    # offset and produce a spurious extra period.
    rule_coincides_with_boundary = last_included_rule && upper_limit == until_utc
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
          zone_abbr:
            TzUtil.period_abbrevation(
              zone_line.format,
              std_off,
              utc_off,
              resolve_letter(letter, zone_rules)
            )
        }

    no_more_rules = rules_tail == []
    no_more_years = tl(years) == []

    cond do
      # The rule fires at the exact same instant the zone line ends: hand its
      # effect off to the next zone line rather than dropping it.
      rule_coincides_with_boundary ->
        tail =
          h_calc_next_zone_line_with_rule(
            btz_data,
            until_utc,
            zone_line_tl,
            rule,
            year,
            rules_tail
          )

        if period == nil, do: tail, else: [period | tail]

      # If we've hit the upper time boundary of this zone line, we do not need to examine any more
      # rules for this rule set.
      last_included_rule ->
        h_calc_next_zone_line(btz_data, period, until_utc, zone_line_tl, letter)

      # There are no more rules or years to consider, but the zone line has an explicit `until`
      # that lies after the last rule transition. We still need to emit the remaining span (from
      # the last transition up to the zone line's `until`, using the offset the last rule left in
      # effect) before moving on to the next zone line. Recursing into calc_rule_periods/8 with an
      # empty year list recomputes the zone line's `until` with that offset and handles the hand-off.
      # Without this, the final span is dropped and the next zone line starts too early
      # (e.g. Africa/Casablanca in tzdata 2026c: Morocco's rules end in March 2026 but the zone
      # line runs until 20 September 2026, when the switch to permanent UTC actually happens).
      no_more_years && no_more_rules && is_integer(upper_limit) ->
        tail =
          calc_rule_periods(
            btz_data,
            [zone_line | zone_line_tl],
            until_utc,
            utc_off,
            rule.save,
            [],
            zone_rules,
            rule.letter
          )

        if period == nil, do: tail, else: [period | tail]

      # There are no more rules or years and the zone line runs until :max. The current period is
      # the last precompiled one; dynamic periods take over beyond this point.
      no_more_years && no_more_rules ->
        h_calc_next_zone_line(btz_data, period, until_utc, zone_line_tl, letter)

      true ->
        tail =
          cond do
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

        if period == nil, do: tail, else: [period | tail]
    end
  end

  # `letter` is `nil` when no rule of the current named rule set has taken
  # effect yet (e.g. a zone line's start predates the earliest rule in the
  # rule set it references). In that case we fall back to the rule set's own
  # standard-time (SAVE == 0) letter, rather than an arbitrary/blank one, so
  # that e.g. America/Regina is "MST" (not "MT") and Antarctica/Troll is
  # "UTC" (not "") before their first rule ever fires. Once any rule has
  # actually applied, `letter` is always that rule's own (non-nil) letter,
  # so this fallback never overrides a real, continuing DST/standard state.
  defp resolve_letter(nil, zone_rules), do: default_letter(zone_rules)
  defp resolve_letter(letter, _zone_rules), do: letter

  defp default_letter(zone_rules) do
    case zone_rules |> Enum.filter(&(&1.save == 0)) |> Enum.sort_by(& &1.from) do
      [rule | _] -> rule.letter
      [] -> ""
    end
  end

  # earliest rule first
  # sort by month!
  def sort_rules_by_time(rules, year) do
    # n.b., we can have many rules per month - such as time changes for religious festivals
    rules
    |> Enum.map(&{&1, TzUtil.tz_day_to_date(year, &1.in, &1.on)})
    |> Enum.sort(&(elem(&1, 1) < elem(&2, 1)))
    |> Enum.map(&elem(&1, 0))
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
    TzUtil.datetime_to_gregorian_seconds(datetime)
  end

  def datetime_to_utc({datetime, modifier}, utc_off, _) when modifier == :standard do
    TzUtil.datetime_to_gregorian_seconds(datetime) - utc_off
  end

  def datetime_to_utc({datetime, modifier}, utc_off, std_off) when modifier == :wall do
    TzUtil.datetime_to_gregorian_seconds(datetime) - utc_off - std_off
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
