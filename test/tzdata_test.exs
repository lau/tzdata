defmodule TzdataTest do
  use ExUnit.Case
  doctest Tzdata

  test "Periods for UTC time in zone with DST around DST changes" do
    gregorian_seconds_point_in_time =
      ~N[2018-10-28T01:00:00]
      |> NaiveDateTime.to_erl()
      |> :calendar.datetime_to_gregorian_seconds()

    assert Tzdata.periods_for_time("Europe/Copenhagen", gregorian_seconds_point_in_time, :utc) ==
             [
               %{
                 from: %{
                   standard: 63_707_911_200,
                   utc: 63_707_907_600,
                   wall: 63_707_911_200
                 },
                 std_off: 0,
                 until: %{
                   standard: 63_721_216_800,
                   utc: 63_721_213_200,
                   wall: 63_721_216_800
                 },
                 utc_off: 3600,
                 zone_abbr: "CET"
               }
             ]
  end

  test "Periods for wall time just after DST changes" do
    gregorian_seconds_point_in_time =
      ~N[2018-10-28 03:00:00]
      |> NaiveDateTime.to_erl()
      |> :calendar.datetime_to_gregorian_seconds()

    assert Tzdata.periods_for_time("Europe/Copenhagen", gregorian_seconds_point_in_time, :wall) ==
             [
               %{
                 from: %{
                   standard: 63_707_911_200,
                   utc: 63_707_907_600,
                   wall: 63_707_911_200
                 },
                 std_off: 0,
                 until: %{
                   standard: 63_721_216_800,
                   utc: 63_721_213_200,
                   wall: 63_721_216_800
                 },
                 utc_off: 3600,
                 zone_abbr: "CET"
               }
             ]
  end

  test "Get periods for point in time far away in the future. For all timezones." do
    # roughly 150 years from now
    point_in_time = :calendar.universal_time |> :calendar.datetime_to_gregorian_seconds |> Kernel.+(3600*24*365*150)
    # This should not raise any exceptions
    Tzdata.zone_list |> Enum.map(&(Tzdata.periods_for_time(&1, point_in_time, :wall)))
  end

  test "time for going on DST should be the same in the far future for zones without changes" do
    zone_name = "Europe/Copenhagen" # This test must change if this zone changes
    about_150_years_from_now = :calendar.universal_time |> :calendar.datetime_to_gregorian_seconds |> Kernel.+(3600*24*365*150)
    {{year, _month, _day}, time} = :calendar.gregorian_seconds_to_datetime(about_150_years_from_now)
    feb_first_close = {{year-150, 2, 1}, time} |> :calendar.datetime_to_gregorian_seconds
    feb_first_in_a_long_time = {{year, 2, 1}, time} |> :calendar.datetime_to_gregorian_seconds
    p1 = Tzdata.periods_for_time(zone_name, feb_first_close, :wall) |> hd
    p2 = Tzdata.periods_for_time(zone_name, feb_first_in_a_long_time, :wall) |> hd
    {_p1_date, p1_time} = p1.from.wall |> :calendar.gregorian_seconds_to_datetime
    {_p2_date, p2_time} = p2.from.wall |> :calendar.gregorian_seconds_to_datetime
    assert p1_time == p2_time
  end
end
