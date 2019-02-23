defmodule Tzdata.ReleaseUpdater do
  @moduledoc false

  require Logger
  use GenServer
  alias Tzdata.DataLoader

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: :tzdata_release_updater)
  end

  def init([]) do
    Process.send_after(self(), :check_if_time_to_update, 3000)
    {:ok, []}
  end

  @msecs_between_checking_date 18_000_000
  def handle_info(:check_if_time_to_update, state) do
    check_if_time_to_update()
    Process.send_after(self(), :check_if_time_to_update, @msecs_between_checking_date)
    {:noreply, state}
  end

  @days_between_remote_poll 1
  def check_if_time_to_update do
    {tag, days} = DataLoader.days_since_last_remote_poll()

    case tag do
      :ok ->
        if days >= @days_between_remote_poll do
          poll_for_update()
        end

      _ ->
        poll_for_update()
    end
  end

  def poll_for_update do
    Logger.debug("Tzdata polling for update.")

    case loaded_tzdata_matches_newest_one?() do
      {:ok, true} ->
        Logger.debug("Tzdata polling shows the loaded tz database is up to date.")
        :do_nothing

      {:ok, false} ->
        case Tzdata.DataBuilder.load_and_save_table() do
          {:ok, _, _} ->
            Tzdata.EtsHolder.new_release_has_been_downloaded()

          {:error, error} ->
            {:error, error}
        end

      _ ->
        :do_nothing
    end
  end

  defp loaded_tzdata_matches_newest_one? do
    case Tzdata.ReleaseReader.has_modified_at?() do
      true -> loaded_tzdata_matches_remote_last_modified?()
      false -> loaded_tzdata_matches_iana_file_size?()
    end
  end

  defp loaded_tzdata_matches_iana_file_size? do
    {tag, filesize} = Tzdata.DataLoader.latest_file_size()

    case tag do
      :ok ->
        {:ok, filesize == Tzdata.ReleaseReader.archive_content_length()}

      _ ->
        {tag, nil}
    end
  end

  defp loaded_tzdata_matches_remote_last_modified? do
    {tag, candidate_last_modified} = Tzdata.DataLoader.last_modified_of_latest_available()

    case tag do
      :ok ->
        current_last_modified = Tzdata.ReleaseReader.modified_at()

        if candidate_last_modified != current_last_modified do
          ("tzdata release in place is from a file last modified #{current_last_modified}. " <>
             "Release file on server was last modified #{candidate_last_modified}.")
          |> Logger.info()
        end

        {:ok, candidate_last_modified == current_last_modified}

      _ ->
        {tag, nil}
    end
  end
end
