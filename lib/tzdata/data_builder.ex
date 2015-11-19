defmodule Tzdata.DataBuilder do
  alias Tzdata.DataLoader
  alias Tzdata.PeriodBuilder
  alias Tzdata.LeapSecParser

  # download new data releases, then parse them, build
  # periods and save the data in an ETS table
  def load_and_save_table do
    {:ok, content_length, release_version, tzdata_dir} = DataLoader.download_new
    ets_table_name = ets_table_name_for_release_version(release_version)
    table = :ets.new(ets_table_name, [:set, :named_table])
    {:ok, map} = Tzdata.BasicDataMap.from_files_in_dir(tzdata_dir)
    :ets.insert(table, {:release_version, release_version})
    :ets.insert(table, {:archive_content_length, content_length})
    :ets.insert(table, {:rules, map.rules})
    :ets.insert(table, {:zones, map.zones})
    :ets.insert(table, {:links, map.links})
    :ets.insert(table, {:zone_list, map.zone_list})
    :ets.insert(table, {:link_list, map.link_list})
    :ets.insert(table, {:zone_and_link_list, map.zone_and_link_list})
    :ets.insert(table, {:by_group, map.by_group})
    :ets.insert(table, {:leap_sec_data, leap_sec_data(tzdata_dir)})
    map.zone_list |> Enum.each(fn zone_name ->
      insert_periods_for_zone(table, map, zone_name)
    end)
    File.rm_rf(tzdata_dir) # remove temporary tzdata dir
    ets_tmp_file_name = "#{release_dir}/#{release_version}.tmp"
    ets_file_name = ets_file_name_for_release_version(release_version)
    File.mkdir_p(release_dir)
    # Create file using a .tmp line ending to avoid it being
    # recognized as a complete file before writing to it is complete.
    :ets.tab2file(table, :erlang.binary_to_list(ets_tmp_file_name))
    :ets.delete(table)
    # Then rename it, which should be an atomic operation.
    :file.rename(ets_tmp_file_name, ets_file_name)
    {:ok, content_length, release_version}
  end
  defp leap_sec_data(tzdata_dir), do: LeapSecParser.read_file(tzdata_dir)

  def ets_file_name_for_release_version(release_version) do
    "#{release_dir}/#{release_version}.ets"
  end

  def ets_table_name_for_release_version(release_version) do
    String.to_atom("tzdata_rel_#{release_version}")
  end

  defp insert_periods_for_zone(table, map, zone_name) do
    key = String.to_atom(zone_name)
    periods = PeriodBuilder.calc_periods(map, zone_name)
    tuple_periods = periods |> Enum.map(fn period ->
      period_to_tuple(key, period)
    end)
    :ets.insert(table, {key, tuple_periods})
  end
  defp period_to_tuple(key, period) do
    {key,
     period.from.utc,
     period.from.wall,
     period.from.standard,
     period.until.utc,
     period.until.wall,
     period.until.standard,
     period.utc_off,
     period.std_off,
     period.zone_abbr,
    }
  end

  defp release_dir do
    Tzdata.Util.data_dir <> "/release_ets"
  end
end
