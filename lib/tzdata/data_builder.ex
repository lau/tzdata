defmodule Tzdata.DataBuilder do
  alias Tzdata.DataLoader
  alias Tzdata.PeriodBuilder

  # download new data releases, then parse them, build
  # periods and save the data in an ETS table
  @release_dir  "priv/release_ets/"
  def load_and_save_table do
    {:ok, content_length, release_version, tzdata_dir} = DataLoader.download_new
    ets_table_name = ets_table_name_for_release_version(release_version)
    table = :ets.new(ets_table_name, [:bag, :named_table])
    map = Tzdata.BasicDataMap.from_files_in_dir(tzdata_dir)
    File.rm_rf(tzdata_dir) # remove temporary tzdata dir
    :ets.insert(table, {:release_version, release_version})
    :ets.insert(table, {:archive_content_length, content_length})
    :ets.insert(table, {:rules, map.rules})
    :ets.insert(table, {:zones, map.zones})
    :ets.insert(table, {:links, map.links})
    :ets.insert(table, {:zone_list, map.zone_list})
    :ets.insert(table, {:link_list, map.link_list})
    :ets.insert(table, {:zone_and_link_list, map.zone_and_link_list})
    :ets.insert(table, {:by_group, map.by_group})
    map.zone_list |> Enum.each(fn zone_name ->
      insert_periods_for_zone(table, map, zone_name)
    end)
    ets_tmp_file_name = "#{@release_dir}#{release_version}.tmp"
    ets_file_name = ets_file_name_for_release_version(release_version)
    File.mkdir_p(@release_dir)
    # Create file using a .tmp line ending to avoid it being
    # recognized as a complete file before writing to it is complete.
    :ets.tab2file(table, :erlang.binary_to_list(ets_tmp_file_name))
    :ets.delete(table)
    # Then rename it, which should be an atomic operation.
    :file.rename(String.to_atom(ets_tmp_file_name), String.to_atom(ets_file_name))
    {:ok, content_length, release_version}
  end
  def ets_file_name_for_release_version(release_version) do
    "#{@release_dir}#{release_version}.ets"
  end

  def ets_table_name_for_release_version(release_version) do
    String.to_atom("tzdata_rel_#{release_version}")
  end

  defp insert_periods_for_zone(table, map, zone_name) do
    key = String.to_atom(zone_name)
    periods = PeriodBuilder.calc_periods(map, zone_name)
    periods |> Enum.each(fn period ->
      :ets.insert(table, period_to_tuple(key, period))
    end)
  end
  defp period_to_tuple(key, period) do
    {key,
     period.from.utc       |> min_max_to_int,
     period.from.wall      |> min_max_to_int,
     period.from.standard  |> min_max_to_int,
     period.until.utc      |> min_max_to_int,
     period.until.wall     |> min_max_to_int,
     period.until.standard |> min_max_to_int,
     period.utc_off,
     period.std_off,
     period.zone_abbr,
    }
  end
  @high_number_to_represent_max 500_000_000_000 # high number equivalent to sometime in the year 15844
  defp min_max_to_int(:min), do: 0
  defp min_max_to_int(:max), do: @high_number_to_represent_max
  defp min_max_to_int(val), do: val
end
