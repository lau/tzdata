defmodule Tzdata.PeriodBuilder do
  @moduledoc false

  alias Tzdata.Util, as: Util
  # the last year to use when precalcuating rules that go into the future
  # indefinitely
  @years_in_the_future_where_precompiled_periods_are_used 40
  @extra_years_to_precompile 4
  @future_years_in_seconds (@years_in_the_future_where_precompiled_periods_are_used +
                              @extra_years_to_precompile) * 31_556_736
  @max_gregorian_for_rules :calendar.universal_time()
                           |> :calendar.datetime_to_gregorian_seconds()
                           |> Kernel.+(@future_years_in_seconds)

  defmodule State do
    defstruct utc_off: 0,
              std_off: 0,
              letter: :undefined,
              utc_from: :min
  end

  alias __MODULE__.State

  def calc_periods(btz_data, zone_name) do
    {:ok, zone} = Map.fetch(btz_data.zones, zone_name)

    {periods, _} =
      Enum.flat_map_reduce(zone.zone_lines, %State{}, &calc_periods_for_line(btz_data, &1, &2))

    combine_periods(periods, [])
  end

  def calc_periods_for_line(_btz_data, %{rules: nil} = zone_line, state) do
    state = %{state | std_off: 0}
    build_period(zone_line, state)
  end

  def calc_periods_for_line(_btz_data, %{rules: {:amount, std_off}} = zone_line, state) do
    state = %{state | std_off: std_off}
    build_period(zone_line, state)
  end

  def calc_periods_for_line(btz_data, %{rules: {:named_rules, rule_name}} = zone_line, state) do
    {:ok, rules} = Map.fetch(btz_data.rules, rule_name)
    calc_named_rule_periods(zone_line, state, rules)
  end

  def combine_periods([first, second | rest], acc) do
    if first.std_off == second.std_off and first.utc_off == second.utc_off and
         first.zone_abbr == second.zone_abbr do
      combined = Map.put(first, :until, second.until)
      combine_periods([combined | rest], acc)
    else
      combine_periods([second | rest], [first | acc])
    end
  end

  def combine_periods(rest, acc) do
    Enum.reverse(acc, rest)
  end

  defp calc_named_rule_periods(zone_line, state, [_ | _] = rules) do
    utc_off = zone_line.gmtoff
    std_off = state.std_off
    zone_until = zone_until(zone_line, utc_off, std_off)
    state = ensure_letter(state, rules)
    rules = Enum.sort_by(rules, &{&1.in, &1.from})

    case next_rule_by_time(rules, state.utc_from, utc_off, std_off) do
      nil ->
        # no rule for the rest of the year. the current period goes until the
        # start of next year, or the end of the period, whichever comes first
        end_of_year = end_of_year_utc(state.utc_from, utc_off, std_off)
        {[period], state} = build_period(zone_line, state, min(end_of_year, zone_until))

        {periods, state} =
          if end_of_year < zone_until and end_of_year < @max_gregorian_for_rules do
            rules = filter_rules_after(rules, period)
            calc_named_rule_periods(zone_line, state, rules)
          else
            {[], state}
          end

        {[period | periods], state}

      {utc_until, rule} when utc_until < zone_until ->
        # transition happens at utc_until, and the new state should have the values from rule
        {[period], state} = build_period(zone_line, state, utc_until)
        state = %{state | std_off: rule.save, letter: rule.letter}
        rules = filter_rules_after(rules, period)
        {periods, state} = calc_named_rule_periods(zone_line, state, rules)
        {[period | periods], state}

      {^zone_until, rule} ->
        # next transition happens when the zone ends: update the state but
        # otherwise build a normal period
        {periods, state} = build_period(zone_line, state)
        state = %{state | std_off: rule.save, letter: rule.letter}
        {periods, state}

      {_, _} ->
        # next transition happens after the zone ends: build a normal period
        build_period(zone_line, state)
    end
  end

  defp calc_named_rule_periods(zone_line, state, []) do
    # no more valid rules; the current one goes to the end of the zone line
    build_period(zone_line, state)
  end

  defp filter_rules_after(rules, period) do
    {{year, _, _}, _} = :calendar.gregorian_seconds_to_datetime(period.until.standard)
    Enum.filter(rules, &Util.rule_applies_after_year?(&1, year))
  end

  defp build_period(zone_line, state, until \\ nil) do
    %{
      gmtoff: utc_off,
      format: format
    } = zone_line

    %{
      utc_from: utc_from,
      std_off: std_off,
      letter: letter
    } = state

    utc_until =
      if until do
        until
      else
        zone_until(zone_line, utc_off, std_off)
      end

    period = %{
      std_off: std_off,
      utc_off: utc_off,
      zone_abbr: Util.period_abbrevation(format, std_off, letter),
      from: times_from_utc(utc_from, utc_off, std_off),
      until: times_from_utc(utc_until, utc_off, std_off)
    }

    state = %{state | utc_off: utc_off, utc_from: utc_until}
    {[period], state}
  end

  defp zone_until(%{until: datetime}, utc_off, std_off) do
    Util.datetime_to_utc(datetime, utc_off, std_off)
  end

  defp zone_until(%{}, _, _) do
    :max
  end

  defp times_from_utc(utc_time, utc_off, std_off) when is_integer(utc_time) do
    %{utc: utc_time, standard: utc_time + utc_off, wall: utc_time + utc_off + std_off}
  end

  defp times_from_utc(utc_time, _, _) when utc_time in [:min, :max] do
    %{utc: utc_time, standard: utc_time, wall: utc_time}
  end

  defp end_of_year_utc(seconds, utc_off, std_off) do
    {{year, _, _}, _} = :calendar.gregorian_seconds_to_datetime(seconds + utc_off)
    Util.datetime_to_utc({{{year + 1, 1, 1}, {0, 0, 0}}, :standard}, utc_off, std_off)
  end

  defp ensure_letter(%{letter: binary} = state, _) when is_binary(binary) do
    state
  end

  defp ensure_letter(%{letter: :undefined} = state, rules) do
    letter = Enum.find_value(rules, &(&1.save == 0 && &1.letter))
    %{state | letter: letter}
  end

  defp next_rule_by_time(rules, utc_seconds, utc_off, std_off) when is_integer(utc_seconds) do
    {wall_day, _} = :calendar.gregorian_seconds_to_datetime(utc_seconds + utc_off + std_off)
    next_rule_by_date(rules, wall_day, utc_seconds, utc_off, std_off)
  end

  defp next_rule_by_time(rules, :min, utc_off, std_off) do
    # we transition at the start of the first rule
    rule = Enum.min_by(rules, &{&1.from, &1.in})
    rule_dt = Util.time_for_rule(rule, rule.from)
    rule_utc = Util.datetime_to_utc(rule_dt, utc_off, std_off)
    {rule_utc, rule}
  end

  defp next_rule_by_date([rule | rules], date, utc_seconds, utc_off, std_off) do
    {wall_year, wall_month, wall_day} = date

    result =
      if Util.rule_applies_for_year(rule, wall_year) do
        {{{_, month, day}, _}, _} = rule_dt = Util.time_for_rule(rule, wall_year)

        if {month, day} > {wall_month, wall_day} do
          rule_utc = Util.datetime_to_utc(rule_dt, utc_off, std_off)

          if rule_utc > utc_seconds do
            {rule_utc, rule}
          end
        end
      end

    if result do
      result
    else
      next_rule_by_date(rules, date, utc_seconds, utc_off, std_off)
    end
  end

  defp next_rule_by_date([], _, _, _, _) do
    nil
  end
end
