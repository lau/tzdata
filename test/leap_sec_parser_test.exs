defmodule LeapSecParserTest do
  use ExUnit.Case, async: true

  test "read and process file" do
    processed = Tzdata.LeapSecParser.read_file("test/tzdata_fixtures/source_data/")

    # leap-seconds.list contains a "dummy line" for a second around new years
    # between 1971 and 1972. This was not a leap second and should be excluded.
    assert processed == %{
             leap_seconds: [
               %{date_time: {{1972, 6, 30}, {23, 59, 60}}, tai_diff: 11},
               %{date_time: {{1972, 12, 31}, {23, 59, 60}}, tai_diff: 12},
               %{date_time: {{1973, 12, 31}, {23, 59, 60}}, tai_diff: 13},
               %{date_time: {{1974, 12, 31}, {23, 59, 60}}, tai_diff: 14},
               %{date_time: {{1975, 12, 31}, {23, 59, 60}}, tai_diff: 15},
               %{date_time: {{1976, 12, 31}, {23, 59, 60}}, tai_diff: 16},
               %{date_time: {{1977, 12, 31}, {23, 59, 60}}, tai_diff: 17},
               %{date_time: {{1978, 12, 31}, {23, 59, 60}}, tai_diff: 18},
               %{date_time: {{1979, 12, 31}, {23, 59, 60}}, tai_diff: 19},
               %{date_time: {{1981, 6, 30}, {23, 59, 60}}, tai_diff: 20},
               %{date_time: {{1982, 6, 30}, {23, 59, 60}}, tai_diff: 21},
               %{date_time: {{1983, 6, 30}, {23, 59, 60}}, tai_diff: 22},
               %{date_time: {{1985, 6, 30}, {23, 59, 60}}, tai_diff: 23},
               %{date_time: {{1987, 12, 31}, {23, 59, 60}}, tai_diff: 24},
               %{date_time: {{1989, 12, 31}, {23, 59, 60}}, tai_diff: 25},
               %{date_time: {{1990, 12, 31}, {23, 59, 60}}, tai_diff: 26},
               %{date_time: {{1992, 6, 30}, {23, 59, 60}}, tai_diff: 27},
               %{date_time: {{1993, 6, 30}, {23, 59, 60}}, tai_diff: 28},
               %{date_time: {{1994, 6, 30}, {23, 59, 60}}, tai_diff: 29},
               %{date_time: {{1995, 12, 31}, {23, 59, 60}}, tai_diff: 30},
               %{date_time: {{1997, 6, 30}, {23, 59, 60}}, tai_diff: 31},
               %{date_time: {{1998, 12, 31}, {23, 59, 60}}, tai_diff: 32},
               %{date_time: {{2005, 12, 31}, {23, 59, 60}}, tai_diff: 33},
               %{date_time: {{2008, 12, 31}, {23, 59, 60}}, tai_diff: 34},
               %{date_time: {{2012, 6, 30}, {23, 59, 60}}, tai_diff: 35},
               %{date_time: {{2015, 6, 30}, {23, 59, 60}}, tai_diff: 36}
             ],
             valid_until: {{2016, 6, 28}, {0, 0, 0}}
           }
  end
end
