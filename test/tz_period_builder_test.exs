defmodule Tzdata.PeriodBuilderTest do
  use ExUnit.Case, async: true
  import Tzdata.PeriodBuilder

  @fixtures_dir "test/tzdata_fixtures/"
  @source_data_dir "#{@fixtures_dir}source_data/"

  @doc "Convert an ISO time to Gregorian seconds"
  defmacro sigil_G({:<<>>, _, [string]}, []) do
    string
    |> from_iso8601
    |> :calendar.datetime_to_gregorian_seconds()
    |> Macro.escape()
  end

  defp from_iso8601(
         <<year::4-bytes, ?-, month::2-bytes, ?-, day::2-bytes, ?T, hour::2-bytes, ?:,
           min::2-bytes, ?:, sec::2-bytes>>
       ) do
    {year, ""} = Integer.parse(year)
    {month, ""} = Integer.parse(month)
    {day, ""} = Integer.parse(day)
    {hour, ""} = Integer.parse(hour)
    {min, ""} = Integer.parse(min)
    {sec, ""} = Integer.parse(sec)
    {{year, month, day}, {hour, min, sec}}
  end

  setup_all do
    {:ok, map} = Tzdata.BasicDataMap.from_files_in_dir(@source_data_dir)
    {:ok, %{map: map}}
  end

  def convert(utc, location) do
    case utc do
      atom when is_atom(utc) -> atom
      utc ->
        :calendar.gregorian_seconds_to_datetime(utc + 60*60*3)
        |> NaiveDateTime.from_erl!()
    end
  end

  def test_for_overlaps(map, location) do
    result = calc_periods(map, location)
    |> Enum.map(fn period ->
      IO.puts("#{convert(period.from.utc, location)}..#{convert(period.until.utc, location)} #{period.from.utc} #{period.until.utc}")
      period
    end)
    |> Enum.reduce_while(nil, fn period, last ->
      %{from: %{utc: from_utc}, until: %{utc: until_utc}, zone_abbr: zone_abbr} = period
      # preconditions
      assert from_utc != :max # period can't start at :max
      assert until_utc != :min # period can't finish at :min
      assert from_utc == :min || until_utc == :max || from_utc < until_utc,
        "#{location}: #{convert(from_utc, location)} >= #{convert(until_utc, location)}" # 'from' must precede 'until' time
      case last do
        nil -> {:cont, {:ok, period}}
        {:ok, last} ->
          # check if this period overlaps with prior period
          coincident = last.until.utc == :max || last.until.utc != :min && from_utc < last.until.utc
          non_sequential = last.until.utc != from_utc
          if coincident || non_sequential do
            conflicts = if coincident, do: " coincident", else: ""
              <> if non_sequential, do: " non-sequential", else: ""
            {:halt, {:error,
              "Location #{location}: #{convert(last.from.utc, location)}..#{convert(last.until.utc, location)} #{last.zone_abbr}"
              <> "... is#{conflicts} with ..."
              <> "#{convert(from_utc, location)}..#{convert(until_utc, location)} #{zone_abbr}"
            }}
          else
            {:cont, {:ok, period}}
          end
      end
    end)
    assert {:ok, _last} = result
  end

  describe "special case time zones with overlap" do
    setup do
      {:ok, map} = Tzdata.BasicDataMap.from_single_file_in_dir(@fixtures_dir, "rule_overlap")
      {:ok, %{map: map}}
    end
    test "will handle coincidence of a rule time change with a subsequent time change", %{map: map} do
      # ["America/Whitehorse", "America/Santiago", "Pacific/Easter", "Pacific/Easter", "Bahia/Banderas", "Asia/Gaza"]
      ["Asia/Gaza"]
      |> Enum.each(&(test_for_overlaps(map, &1)))
    end
  end

  test "sourc data has no time period overlaps", %{map: map} do
    map.zone_list
    |> Enum.each(&(test_for_overlaps(map, &1)))
  end

  test "can calculate for zones with one line", %{map: map} do
    periods = calc_periods(map, "Etc/UTC")

    assert periods == [
             %{
               std_off: 0,
               utc_off: 0,
               zone_abbr: "UTC",
               from: %{utc: :min, standard: :min, wall: :min},
               until: %{utc: :max, standard: :max, wall: :max}
             }
           ]

    periods = calc_periods(map, "Etc/GMT-10")

    assert periods == [
             %{
               std_off: 0,
               utc_off: 36000,
               zone_abbr: "GMT-10",
               from: %{utc: :min, standard: :min, wall: :min},
               until: %{utc: :max, standard: :max, wall: :max}
             }
           ]
  end

  test "can calculate for zones with multiple lines", %{map: map} do
    periods = calc_periods(map, "Africa/Abidjan")
    assert [first, second] = periods

    assert first == %{
             std_off: 0,
             utc_off: -968,
             zone_abbr: "LMT",
             from: %{utc: :min, standard: :min, wall: :min},
             until: %{
               utc: ~G[1912-01-01T00:16:08],
               standard: ~G[1912-01-01T00:00:00],
               wall: ~G[1912-01-01T00:00:00]
             }
           }

    assert second == %{
             std_off: 0,
             utc_off: 0,
             zone_abbr: "GMT",
             from: %{
               utc: ~G[1912-01-01T00:16:08],
               standard: ~G[1912-01-01T00:16:08],
               wall: ~G[1912-01-01T00:16:08]
             },
             until: %{utc: :max, standard: :max, wall: :max}
           }
  end

  test "can calculate for zones with static offset rules", %{map: map} do
    periods = calc_periods(map, "Atlantic/Cape_Verde")
    assert [_lmt, _cvt_1, cvst, cvt_2, _cvt_3] = periods

    assert cvst == %{
             std_off: 3600,
             utc_off: -7200,
             zone_abbr: "CVST",
             from: %{
               utc: ~G[1942-09-01T02:00:00],
               standard: ~G[1942-09-01T00:00:00],
               wall: ~G[1942-09-01T01:00:00]
             },
             until: %{
               utc: ~G[1945-10-15T01:00:00],
               standard: ~G[1945-10-14T23:00:00],
               wall: ~G[1945-10-15T00:00:00]
             }
           }

    assert cvt_2 == %{
             std_off: 0,
             utc_off: -7200,
             zone_abbr: "CVT",
             from: %{
               utc: ~G[1945-10-15T01:00:00],
               standard: ~G[1945-10-14T23:00:00],
               wall: ~G[1945-10-14T23:00:00]
             },
             until: %{
               utc: ~G[1975-11-25T04:00:00],
               standard: ~G[1975-11-25T02:00:00],
               wall: ~G[1975-11-25T02:00:00]
             }
           }
  end

  @tag :skip
  test "can calculate simple DST rules going into the future", %{map: map} do
    periods = calc_periods(map, "Antarctica/Troll")
    [_zzz, std_1, dst_1, std_2 | _] = periods

    assert std_1 == %{
             std_off: 0,
             utc_off: 0,
             zone_abbr: "UTC",
             from: %{
               utc: ~G[2005-02-12T00:00:00],
               standard: ~G[2005-02-12T00:00:00],
               wall: ~G[2005-02-12T00:00:00]
             },
             until: %{
               utc: ~G[2005-03-27T01:00:00],
               standard: ~G[2005-03-27T01:00:00],
               wall: ~G[2005-03-27T01:00:00]
             }
           }

    assert dst_1 == %{
             std_off: 7200,
             utc_off: 0,
             zone_abbr: "CEST",
             from: %{
               utc: ~G[2005-03-27T01:00:00],
               standard: ~G[2005-03-27T01:00:00],
               wall: ~G[2005-03-27T03:00:00]
             },
             until: %{
               utc: ~G[2005-10-30T01:00:00],
               standard: ~G[2005-10-30T01:00:00],
               wall: ~G[2005-10-30T03:00:00]
             }
           }

    assert std_2 == %{
             std_off: 0,
             utc_off: 0,
             zone_abbr: "UTC",
             from: %{
               utc: ~G[2005-10-30T01:00:00],
               standard: ~G[2005-10-30T01:00:00],
               wall: ~G[2005-10-30T01:00:00]
             },
             until: %{
               utc: ~G[2006-03-26T01:00:00],
               standard: ~G[2006-03-26T01:00:00],
               wall: ~G[2006-03-26T01:00:00]
             }
           }

    # 40 years, 2 DST transitions per year
    assert length(periods) > 80
  end

  test "calculate periods for zone where last line has no rules", %{map: map} do
    assert [_, _] = calc_periods(map, "Africa/Abidjan")
  end

  @tag :skip
  test "calculates correct abbreviation when changing no rule", %{map: map} do
    periods = calc_periods(map, "America/Chihuahua")
    # changed from static CST to CST/CDT at the start of 1996
    assert Enum.at(periods, 6) ==
             %{
               std_off: 0,
               utc_off: -21600,
               zone_abbr: "CST",
               from: %{
                 wall: ~G[1932-04-01T01:00:00],
                 standard: ~G[1932-04-01T01:00:00],
                 utc: ~G[1932-04-01T07:00:00]
               },
               until: %{
                 wall: ~G[1996-04-07T02:00:00],
                 standard: ~G[1996-04-07T02:00:00],
                 utc: ~G[1996-04-07T08:00:00]
               }
             }

    assert Enum.at(periods, 7) ==
             %{
               std_off: 3600,
               utc_off: -21600,
               zone_abbr: "CDT",
               from: %{
                 wall: ~G[1996-04-07T03:00:00],
                 standard: ~G[1996-04-07T02:00:00],
                 utc: ~G[1996-04-07T08:00:00]
               },
               until: %{
                 wall: ~G[1996-10-27T02:00:00],
                 standard: ~G[1996-10-27T01:00:00],
                 utc: ~G[1996-10-27T07:00:00]
               }
             }

    assert Enum.at(periods, 8) ==
             %{
               std_off: 0,
               utc_off: -21600,
               zone_abbr: "CST",
               from: %{
                 wall: ~G[1996-10-27T01:00:00],
                 standard: ~G[1996-10-27T01:00:00],
                 utc: ~G[1996-10-27T07:00:00]
               },
               until: %{
                 wall: ~G[1997-04-06T02:00:00],
                 standard: ~G[1997-04-06T02:00:00],
                 utc: ~G[1997-04-06T08:00:00]
               }
             }
  end

  @tag :skip
  test "can handle DST rules that aren't active for a year", %{map: map} do
    periods = calc_periods(map, "America/Regina")
    # -7:00 (no offset) in Sep 1905, since there was no Canadian DST utnil 1918
    [_lmt, mst_1905_to_1918, mdt_1918, mst_1918_to_1930 | _] = periods

    assert mst_1905_to_1918 == %{
             std_off: 0,
             utc_off: -25200,
             zone_abbr: "MST",
             from: %{
               wall: ~G[1905-08-31T23:58:36],
               standard: ~G[1905-08-31T23:58:36],
               utc: ~G[1905-09-01T06:58:36]
             },
             until: %{
               wall: ~G[1918-04-14T02:00:00],
               standard: ~G[1918-04-14T02:00:00],
               utc: ~G[1918-04-14T09:00:00]
             }
           }

    assert mdt_1918 == %{
             std_off: 3600,
             utc_off: -25200,
             zone_abbr: "MDT",
             from: %{
               wall: ~G[1918-04-14T03:00:00],
               standard: ~G[1918-04-14T02:00:00],
               utc: ~G[1918-04-14T09:00:00]
             },
             until: %{
               wall: ~G[1918-10-27T02:00:00],
               standard: ~G[1918-10-27T01:00:00],
               utc: ~G[1918-10-27T08:00:00]
             }
           }

    assert mst_1918_to_1930 == %{
             std_off: 0,
             utc_off: -25200,
             zone_abbr: "MST",
             from: %{
               wall: ~G[1918-10-27T01:00:00],
               standard: ~G[1918-10-27T01:00:00],
               utc: ~G[1918-10-27T08:00:00]
             },
             until: %{
               wall: ~G[1930-05-04T00:00:00],
               standard: ~G[1930-05-04T00:00:00],
               utc: ~G[1930-05-04T07:00:00]
             }
           }
  end

  test "can calculate zones which start with a named rule", %{map: map} do
    # also before GMT, so 1901-01-0T00:00:00 is actually 1900-12-31T23:00:00 UTC
    [cet, cest | _] = calc_periods(map, "CET")

    assert cet == %{
             std_off: 0,
             utc_off: 3600,
             zone_abbr: "CET",
             from: %{wall: :min, standard: :min, utc: :min},
             until: %{
               wall: ~G[1916-04-30T23:00:00],
               standard: ~G[1916-04-30T23:00:00],
               utc: ~G[1916-04-30T22:00:00]
             }
           }

    assert cest == %{
             std_off: 3600,
             utc_off: 3600,
             zone_abbr: "CEST",
             from: %{
               wall: ~G[1916-05-01T00:00:00],
               standard: ~G[1916-04-30T23:00:00],
               utc: ~G[1916-04-30T22:00:00]
             },
             until: %{
               wall: ~G[1916-10-01T01:00:00],
               standard: ~G[1916-10-01T00:00:00],
               utc: ~G[1916-09-30T23:00:00]
             }
           }
  end

  test "handles rules which end with a DST transition", %{map: map} do
    periods = calc_periods(map, "Asia/Tokyo")
    [last_dst, last_jst] = Enum.take(periods, -2)

    assert last_dst == %{
             std_off: 3600,
             utc_off: 32400,
             zone_abbr: "JDT",
             from: %{
               wall: ~G[1951-05-06T03:00:00],
               standard: ~G[1951-05-06T02:00:00],
               utc: ~G[1951-05-05T17:00:00]
             },
             until: %{
               wall: ~G[1951-09-08T02:00:00],
               standard: ~G[1951-09-08T01:00:00],
               utc: ~G[1951-09-07T16:00:00]
             }
           }

    assert last_jst == %{
             std_off: 0,
             utc_off: 32400,
             zone_abbr: "JST",
             from: %{
               wall: ~G[1951-09-08T01:00:00],
               standard: ~G[1951-09-08T01:00:00],
               utc: ~G[1951-09-07T16:00:00]
             },
             until: %{wall: :max, standard: :max, utc: :max}
           }
  end

  @tag :skip
  test "handles DST transitions at the same time as zone transitions", %{map: map} do
    periods = calc_periods(map, "America/Argentina/Buenos_Aires")

    assert Enum.at(periods, 53) == %{
             std_off: 0,
             utc_off: -10800,
             zone_abbr: "ART",
             from: %{
               utc: ~G[1993-03-07T02:00:00],
               standard: ~G[1993-03-06T23:00:00],
               wall: ~G[1993-03-06T23:00:00]
             },
             until: %{
               utc: ~G[1999-10-03T03:00:00],
               standard: ~G[1999-10-03T00:00:00],
               wall: ~G[1999-10-03T00:00:00]
             }
           }

    assert Enum.at(periods, 54) == %{
             std_off: 3600,
             utc_off: -14400,
             zone_abbr: "ARST",
             from: %{
               utc: ~G[1999-10-03T03:00:00],
               standard: ~G[1999-10-02T23:00:00],
               wall: ~G[1999-10-03T00:00:00]
             },
             until: %{
               utc: ~G[2000-03-03T03:00:00],
               standard: ~G[2000-03-02T23:00:00],
               wall: ~G[2000-03-03T00:00:00]
             }
           }
  end

  test "no zone periods go back in time", %{map: map} do
    invalid_periods =
      for zone <- map.zone_list,
          period <- calc_periods(map, zone),
          period.from.utc != :min,
          period.until.utc != :max,
          period.from.utc >= period.until.utc do
        {zone, period}
      end

    assert invalid_periods == []
  end

  test "Dublin with negative DST is handled correctly", %{map: map} do
    periods = calc_periods(map, "Europe/Dublin")

    summer_time_period =
      periods
      |> Enum.filter(fn period ->
        period.from.utc != :min and period.from.utc > ~G[2018-03-01T00:00:00] and
          period.until.utc < ~G[2018-12-01T00:00:00]
      end)
      |> hd

    assert summer_time_period == %{
             from: %{
               standard: 63_689_162_400,
               utc: 63_689_158_800,
               wall: 63_689_162_400
             },
             std_off: 0,
             until: %{
               standard: 63_707_911_200,
               utc: 63_707_907_600,
               wall: 63_707_911_200
             },
             utc_off: 3600,
             zone_abbr: "IST"
           }
  end
end
