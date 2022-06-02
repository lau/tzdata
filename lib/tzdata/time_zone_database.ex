defmodule Tzdata.TimeZoneDatabase do
  @behaviour Calendar.TimeZoneDatabase
  @moduledoc """
  Module for interfacing with the standard library time zone related functions of Elixir 1.8+.

  Implements the `Calendar.TimeZoneDatabase` behaviour.
  """

  @impl true
  def time_zone_period_from_utc_iso_days(iso_days, time_zone) do
    {:ok, ndt} = iso_days |> naive_datetime_from_iso_days
    datetime_erl = ndt |> NaiveDateTime.to_erl()
    gregorian_seconds = :calendar.datetime_to_gregorian_seconds(datetime_erl)

    case Tzdata.periods_for_time(time_zone, gregorian_seconds, :utc) do
      [period] ->
        {:ok, old_tz_period_to_new(period)}

      [] ->
        {:error, :time_zone_not_found}

      {:error, :not_found} ->
        {:error, :time_zone_not_found}
    end
  end

  @impl true
  def time_zone_periods_from_wall_datetime(ndt, time_zone) do
    datetime_erl = ndt |> NaiveDateTime.to_erl()
    gregorian_seconds = :calendar.datetime_to_gregorian_seconds(datetime_erl)

    case Tzdata.periods_for_time(time_zone, gregorian_seconds, :wall) do
      [period] ->
        new_period = old_tz_period_to_new(period)
        {:ok, new_period}

      [_p1, _p2] = periods ->
        [p1, p2] =
          periods
          |> Enum.sort_by(fn %{from: %{utc: from_utc}} -> from_utc end)
          |> Enum.map(&old_tz_period_to_new(&1))

        {:ambiguous, p1, p2}

      [] ->
        gap_for_time_zone(time_zone, gregorian_seconds)

      {:error, :not_found} ->
        {:error, :time_zone_not_found}
    end
  end

  @spec gap_for_time_zone(String.t(), non_neg_integer()) ::
          {:error, :time_zone_not_found} | {:gap, [Calendar.TimeZoneDatabase.time_zone_period()]}
  defp gap_for_time_zone(time_zone, gregorian_seconds) do
    # Gap in wall time
    case Tzdata.periods(time_zone) do
      {:error, :not_found} ->
        {:error, :time_zone_not_found}

      {:ok, periods} when is_list(periods) ->
        period_before =
          periods
          |> Enum.filter(fn period -> period.until.wall <= gregorian_seconds end)
          |> Enum.sort_by(fn period -> period.until.utc end)
          |> List.last()
          |> old_tz_period_to_new

        period_after =
          periods
          |> Enum.filter(fn period ->
            period.from.wall > gregorian_seconds or period.from.wall == :min
          end)
          |> Enum.sort_by(fn period -> period.from.utc end)
          |> List.first()
          |> old_tz_period_to_new

        {:gap, {period_before, period_before.until_wall}, {period_after, period_after.from_wall}}
    end
  end

  defp naive_datetime_from_iso_days(iso_days) do
    {year, month, day, hour, minute, second, microsecond} =
      Calendar.ISO.naive_datetime_from_iso_days(iso_days)

    NaiveDateTime.new(year, month, day, hour, minute, second, microsecond)
  end

  @doc !"""
       Takes a time_zone period in the format returned by Tzdata 0.1.x and 0.5.x
       and returns one of the TimeZoneDatabase.time_zone_period type.
       """
  @spec old_tz_period_to_new(Tzdata.time_zone_period()) ::
          Calendar.TimeZoneDatabase.time_zone_period()
  defp old_tz_period_to_new(old_period) do
    %{
      utc_offset: old_period.utc_off,
      std_offset: old_period.std_off,
      zone_abbr: old_period.zone_abbr,
      from_wall: old_period.from.wall |> old_limit_to_new,
      until_wall: old_period.until.wall |> old_limit_to_new
    }
  end

  defp old_limit_to_new(:min = limit), do: limit
  defp old_limit_to_new(:max = limit), do: limit

  defp old_limit_to_new(limit),
    do: limit |> :calendar.gregorian_seconds_to_datetime() |> NaiveDateTime.from_erl!()
end
