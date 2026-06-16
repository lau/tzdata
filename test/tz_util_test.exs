defmodule UtilTest do
  use ExUnit.Case, async: true
  alias Tzdata.Util, as: TzUtil
  alias Tzdata.BasicDataMap
  import TzUtil
  doctest Tzdata.Util

  test "get last weekday of month" do
    # last thursday of Aug 2014 should be on the 28th
    assert TzUtil.last_weekday_of_month(2014, 8, 4) == 28
    # last sunday of Aug 2014 should be on the 31st
    assert TzUtil.last_weekday_of_month(2014, 8, 7) == 31
    # should also accept string with english abbrevations of weekdays
    assert TzUtil.last_weekday_of_month(2014, 8, "sun") == 31
    assert TzUtil.last_weekday_of_month(2014, 8, "thu") == 28
  end

  test "transform 'until' date-time" do
    assert TzUtil.transform_until_datetime("1918 Nov 11 11:00u") == {{{1918,11,11}, {11,0,0}}, :utc}
    assert TzUtil.transform_until_datetime("1940 May 20  2:00s") == {{{1940,5,20}, {2,0,0}}, :standard}
    assert TzUtil.transform_until_datetime("1944 Sep  3") == {{{1944,9,3}, {0,0,0}}, :wall}
    assert TzUtil.transform_until_datetime("1977") == {{{1977,1,1}, {0,0,0}}, :wall}
    assert TzUtil.transform_until_datetime("1992 Sep lastSat 23:00") == {{{1992,9,26}, {23,0,0}}, :wall}
    assert TzUtil.transform_until_datetime("1992 Sep lastSat") == {{{1992,9,26}, {0,0,0}}, :wall}
  end

  test "month_number_for_month_name" do
    assert TzUtil.month_number_for_month_name("Mar") == 3
    assert TzUtil.month_number_for_month_name("mar") == 3
    assert TzUtil.month_number_for_month_name("3") == 3
  end

  test "rules that apply for a certain year" do
    {:ok, map} = BasicDataMap.from_files_in_dir("test/tzdata_fixtures/source_data")
    rules = map[:rules]["Denmark"]
    assert TzUtil.rules_for_year(rules, 1800) == []
    assert TzUtil.rules_for_year(rules, 1915) |> length == 0
    assert TzUtil.rules_for_year(rules, 1916) |> length == 2
    assert TzUtil.rules_for_year(rules, 1917) |> length == 0
  end

  test "Time for rule applying" do
    rule = %{at: {{1, 0, 0}, :utc}, from: 1979, in: 9, letter: "-", name: "EU", on: "lastSun", record_type: :rule, save: 0, to: 1995, type: "-"}
    assert TzUtil.time_for_rule(rule, 1990) == {{{1990, 9, 30}, {1,0,0}}, :utc}

    rule = %{at: {{1, 0, 0}, :wall}, from: 1917, in: 10, letter: "-", name: "Iceland", on: "21", record_type: :rule, save: 0, to: :only, type: "-"}
    assert TzUtil.time_for_rule(rule, 1917) == {{{1917, 10, 21}, {1,0,0}}, :wall}
  end

  test "datetime_to_utc handles end-of-day 24:00 transition times" do
    # The IANA tz database legally uses "24:00" for end-of-day transition
    # boundaries, which transform_until_datetime/time_for_rule parse to an
    # hour-24 tuple (e.g. {{2024, 3, 31}, {24, 0, 0}}). Erlang/OTP 29 tightened
    # :calendar to reject hours outside 0..23, so converting these must treat
    # 24:00 as the equivalent next-day 00:00 rather than crash.
    next_day_midnight = :calendar.datetime_to_gregorian_seconds({{2024, 4, 1}, {0, 0, 0}})

    assert TzUtil.datetime_to_utc({{{2024, 3, 31}, {24, 0, 0}}, :utc}, 0, 0) == next_day_midnight

    assert TzUtil.datetime_to_utc({{{2024, 3, 31}, {24, 0, 0}}, :standard}, 3600, 0) ==
             next_day_midnight - 3600

    assert TzUtil.datetime_to_utc({{{2024, 3, 31}, {24, 0, 0}}, :wall}, 3600, 3600) ==
             next_day_midnight - 3600 - 3600
  end

  test "tz_day_to_date" do
    assert TzUtil.tz_day_to_date(2000, 4, "lastSun") == {2000, 4, 30}
    assert TzUtil.tz_day_to_date(1932, 4, "Sun>=25") == {1932, 5, 1}
    assert TzUtil.tz_day_to_date(2005, 4, "Fri<=1") == {2005, 4, 1}
    assert TzUtil.tz_day_to_date(2005, 4, "Mon<=1") == {2005, 3, 28}
  end
end
