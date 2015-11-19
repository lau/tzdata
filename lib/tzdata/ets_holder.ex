defmodule Tzdata.EtsHolder do
  require Logger
  use GenServer
  alias Tzdata.DataBuilder
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    make_sure_a_release_is_on_file
    create_current_release_ets_table
    {:ok, release_name} = load_release
    {:ok, release_name}
  end

  def new_release_has_been_downloaded do
    GenServer.cast(__MODULE__, :new_release_has_been_downloaded)
  end

  def handle_cast(:new_release_has_been_downloaded, state) do
    {:ok, new_release_name} = load_release
    if state != new_release_name do
      Logger.info "Tzdata has updated the release from #{state} to #{new_release_name}"
      delete_ets_table_for_version(state)
      delete_ets_file_for_version(state)
    end
    {:noreply, new_release_name}
  end
  defp delete_ets_table_for_version(release_version) do
    Logger.debug "Tzdata deleting ETS table for version #{release_version}"
    release_version
    |> DataBuilder.ets_table_name_for_release_version
    |> :ets.delete
  end
  defp delete_ets_file_for_version(release_version) do
    Logger.debug "Tzdata deleting ETS table file for version #{release_version}"
    release_version
    |> DataBuilder.ets_file_name_for_release_version
    |> File.rm
  end

  defp load_release do
    release_name = newest_release_on_file
    load_ets_table(release_name)
    set_current_release(release_name)
    {:ok, release_name}
  end

  defp load_ets_table(release_name) do
    file_name = "#{release_dir}/#{release_name}.ets"
    {:ok, _table} = :ets.file2tab(String.to_char_list(file_name))
  end

  defp create_current_release_ets_table do
    table = :ets.new(:tzdata_current_release, [:set, :named_table])
    {:ok, table}
  end
  defp set_current_release(release_version) do
    #Logger.debug "Tzdata setting current release version to #{release_version}"
    :ets.insert(:tzdata_current_release, {:release_version, release_version})
  end

  defp make_sure_a_release_is_on_file do
    make_sure_a_release_dir_exists
    if length(release_files) == 0 do
      Tzdata.DataBuilder.load_and_save_table
    end
  end
  defp make_sure_a_release_dir_exists do
    File.mkdir(release_dir)
  end

  defp newest_release_on_file do
    release_files
    |> List.last
    |> String.replace(".ets", "")
  end

  defp release_files do
    File.ls!(release_dir)
    |> Enum.filter(&( Regex.match?(~r/^2\d{3}[a-z]\.ets/, &1) ))
    |> Enum.sort
  end

  defp release_dir do
    Tzdata.Util.data_dir <> "/release_ets"
  end
end
