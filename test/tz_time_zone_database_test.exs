defmodule Tzdata.TimeZoneDatabaseTest do
  use ExUnit.Case, async: true
  alias Tzdata.TimeZoneDatabase

  describe "time_zone_periods_from_wall_datetime" do
    test "gap at DST change" do
      cet = %{
        from_wall: ~N[2018-10-28 02:00:00],
        std_offset: 0,
        until_wall: ~N[2019-03-31 02:00:00],
        utc_offset: 3600,
        zone_abbr: "CET"
      }

      cest = %{
        from_wall: ~N[2019-03-31 03:00:00],
        std_offset: 3600,
        until_wall: ~N[2019-10-27 03:00:00],
        utc_offset: 3600,
        zone_abbr: "CEST"
      }

      assert {:gap, {^cet, ~N[2019-03-31 02:00:00]}, {^cest, ~N[2019-03-31 03:00:00]}} =
               TimeZoneDatabase.time_zone_periods_from_wall_datetime(
                 ~N[2019-03-31 02:30:00],
                 "Europe/Copenhagen"
               )

      # Near edge (See #110)
      assert {:gap, {^cet, ~N[2019-03-31 02:00:00]}, {^cest, ~N[2019-03-31 03:00:00]}} =
               TimeZoneDatabase.time_zone_periods_from_wall_datetime(
                 ~N[2019-03-31 02:00:00],
                 "Europe/Copenhagen"
               )

      # Far edge
      assert {:gap, {^cet, ~N[2019-03-31 02:00:00]}, {^cest, ~N[2019-03-31 03:00:00]}} =
               TimeZoneDatabase.time_zone_periods_from_wall_datetime(
                 ~N[2019-03-31 02:59:59],
                 "Europe/Copenhagen"
               )
    end
  end

  test "Zones that use %z for abbreveation" do
    assert {:ok,
            %{
              zone_abbr: "-12",
              utc_offset: -43200,
              std_offset: 0,
              from_wall: :min,
              until_wall: :max
            }} ==
             TimeZoneDatabase.time_zone_periods_from_wall_datetime(
               ~N[2019-03-31 02:59:59],
               "Etc/GMT+12"
             )

    assert {:ok,
            %{
              from_wall: ~N[1937-01-01 00:15:00],
              std_offset: 0,
              until_wall: ~N[1942-08-01 00:00:00],
              utc_offset: 9900,
              zone_abbr: "+0245"
            }} ==
             TimeZoneDatabase.time_zone_periods_from_wall_datetime(
               ~N[1940-01-01 10:59:59],
               "Africa/Nairobi"
             )

    assert {:ok,
            %{
              from_wall: ~N[1978-10-15 02:00:00],
              std_offset: 0,
              until_wall: ~N[1983-07-31 02:00:00],
              utc_offset: 10800,
              zone_abbr: "+03"
            }} ==
             TimeZoneDatabase.time_zone_periods_from_wall_datetime(
               ~N[1983-01-01 10:59:59],
               "Europe/Istanbul"
             )

    assert {:ok,
            %{
              from_wall: ~N[1983-07-31 03:00:00],
              std_offset: 3600,
              until_wall: ~N[1983-10-02 02:00:00],
              utc_offset: 10800,
              zone_abbr: "+04"
            }} ==
             TimeZoneDatabase.time_zone_periods_from_wall_datetime(
               ~N[1983-09-01 10:59:59],
               "Europe/Istanbul"
             )

    assert {:ok,
            %{
              from_wall: ~N[2015-10-04 01:30:00],
              std_offset: 0,
              until_wall: ~N[2019-07-01 00:00:00],
              utc_offset: 39600,
              zone_abbr: "+11"
            }} ==
             TimeZoneDatabase.time_zone_periods_from_wall_datetime(
               ~N[2019-01-01 10:59:59],
               "Pacific/Norfolk"
             )

    assert {:error, :time_zone_not_found} ==
             TimeZoneDatabase.time_zone_periods_from_wall_datetime(
               ~N[2022-11-10 10:59:59],
               "PST"
             )
  end
end
