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
end
