defmodule BasicDataMapTest do
  use ExUnit.Case, async: true
  alias Tzdata.BasicDataMap

  test "Existing rule" do
    {:ok, map} = BasicDataMap.from_files_in_dir("test/tzdata_fixtures/source_data")
    result = map[:rules]["Uruguay"]
    assert hd(result)[:name] == "Uruguay"
  end

  test "Existing zone" do
    {:ok, map} = BasicDataMap.from_files_in_dir("test/tzdata_fixtures/source_data")
    result = map[:zones]["Europe/Copenhagen"]
    assert result[:name] == "Europe/Copenhagen"
  end

  test "trying to get non existing zone should result in error" do
    {:ok, map} = BasicDataMap.from_files_in_dir("test/tzdata_fixtures/source_data")
    result = map[:zones]["Foo/Bar"]
    assert result == nil
  end

  test "trying to get non existing rules should result in error" do
    {:ok, map} = BasicDataMap.from_files_in_dir("test/tzdata_fixtures/source_data")
    result = map[:rules]["Narnia"]
    assert result == nil
  end

  test "Should provide list of zone names and link names" do
    {:ok, map} = BasicDataMap.from_files_in_dir("test/tzdata_fixtures/source_data")
    # London is cononical zone. Jersey is a link
    assert map[:zone_list] |> Enum.member? "Europe/London"
    assert map[:zone_list] |> Enum.member?("Europe/Jersey") != true
    assert map[:link_list] |> Enum.member?("Europe/London") != true
    assert map[:link_list] |> Enum.member? "Europe/Jersey"
    assert map[:zone_and_link_list] |> Enum.member? "Europe/London"
    assert map[:zone_and_link_list] |> Enum.member? "Europe/Jersey"
  end
end
