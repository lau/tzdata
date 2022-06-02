defmodule Tzdata.DataBuilder do
  @moduledoc false
  alias Tzdata.DataLoader
  alias Tzdata.PeriodBuilder
  alias Tzdata.LeapSecParser
  require Logger

  # download new data releases, then parse them, build
  # periods and save the data in an ETS table
  def load_and_save_table do
    {:ok, content_length, release_version, tzdata_dir, modified_at} = DataLoader.download_new()
    current_version = Tzdata.ReleaseReader.release_version()

    if release_version == current_version do
      # remove temporary tzdata dir
      File.rm_rf(tzdata_dir)

      Logger.info(
        "Downloaded tzdata release from IANA is the same version as the version currently in use (#{
          current_version
        })."
      )

      {:error, :downloaded_version_same_as_current_version}
    else
      do_load_and_save_table(content_length, release_version, tzdata_dir, modified_at)
    end
  end

  defp do_load_and_save_table(content_length, release_version, tzdata_dir, modified_at) do
    ets_table_name = ets_table_name_for_release_version(release_version)
    table = :ets.new(ets_table_name, [:bag, :named_table])
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
    :ets.insert(table, {:modified_at, modified_at})

    map.zone_list
    |> Enum.each(fn zone_name ->
         insert_periods_for_zone(table, map, zone_name)
       end)

    # remove temporary tzdata dir
    File.rm_rf(tzdata_dir)
    ets_tmp_file_name = "#{release_dir()}/#{release_version}.tmp"
    ets_file_name = ets_file_name_for_release_version(release_version)
    File.mkdir_p(release_dir())
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
    "#{release_dir()}/#{release_version}.v#{Tzdata.EtsHolder.file_version}.ets"
  end

  def ets_table_name_for_release_version(release_version) do
    String.to_atom("tzdata_rel_#{release_version}")
  end

  defp insert_periods_for_zone(table, map, zone_name) do
    key = String.to_atom(zone_name)
    periods = PeriodBuilder.calc_periods(map, zone_name)

    tuple_periods =
      periods
      |> Enum.map(fn period ->
           period_to_tuple(key, period)
         end)

    tuple_periods |> Enum.each(fn tuple_period ->
      :ets.insert(table, tuple_period)
    end)
  end

  defp period_to_tuple(key, period) do
    {
      key,
      period.from.utc,
      period.from.wall,
      period.from.standard,
      period.until.utc,
      period.until.wall,
      period.until.standard,
      period.utc_off,
      period.std_off,
      period.zone_abbr
    }
  end

  defp release_dir do
    Tzdata.Util.data_dir() <> "/release_ets"
  end
end
