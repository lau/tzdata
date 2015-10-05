defmodule Tzdata.ReleaseUpdater do
  require Logger
  use GenServer
  alias Tzdata.DataLoader

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: :tzdata_release_updater)
  end

  def init([]) do
    Task.async(fn -> :timer.sleep(3000); Tzdata.ReleaseUpdater.check_if_time_to_update end)
    {:ok, []}
  end

  @msecs_between_checking_date 18_000_000
  @days_between_remote_poll 1
  def check_if_time_to_update do
    {tag, days} = DataLoader.days_since_last_remote_poll
    case tag do
      :ok ->
        if days >= @days_between_remote_poll do
          poll_for_update
        end
      _ -> poll_for_update
    end
    Task.async(fn -> :timer.sleep(@msecs_between_checking_date); Tzdata.ReleaseUpdater.check_if_time_to_update end)
  end

  def poll_for_update do
    Logger.debug "Tzdata polling for update."
    case loaded_tzdata_matches_iana_file_size? do
      {:ok, true} ->
        Logger.debug "Tzdata polling shows the loaded tz database is up to date."
        :do_nothing
      {:ok, false} ->
        Tzdata.DataBuilder.load_and_save_table
        Tzdata.EtsHolder.new_release_has_been_downloaded
      _ -> :do_nothing
    end
  end

  defp loaded_tzdata_matches_iana_file_size? do
    {tag, filesize} = Tzdata.DataLoader.latest_file_size
    case tag do
      :ok ->
        {:ok, filesize == Tzdata.ReleaseReader.archive_content_length}
      _ -> {tag, nil}
    end
  end
end
