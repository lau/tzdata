defmodule Tzdata.ReleaseUpdater do
  @moduledoc false

  require Logger
  use GenServer
  alias Tzdata.DataLoader

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: :tzdata_release_updater)
  end

  def init([]) do
    case update_check_status() do
      :ok ->
        Process.send_after(self(), :check_if_time_to_update, 3000)

      {:disabled, reason} ->
        # Stay alive but idle: nothing is polled, downloaded or written.
        Logger.warning(disabled_message(reason))
    end

    {:ok, []}
  end

  @recommended_otp_version "27.3.4.19"

  @doc false
  # Whether automatic update checks can run with the HTTP client that would
  # be used. The built-in `:httpc`-based client is only used when it can
  # verify TLS certificates on the running Erlang/OTP version.
  def update_check_status do
    case Application.get_env(:tzdata, :http_client) do
      client when client in [nil, Tzdata.HTTPClient.Httpc] ->
        case Tzdata.HTTPClient.Httpc.unsafe_reason() do
          nil -> :ok
          reason -> {:disabled, reason}
        end

      client ->
        if Code.ensure_loaded?(client) do
          :ok
        else
          {:disabled, {:http_client_not_available, client}}
        end
    end
  end

  @doc false
  def disabled_message(reason) do
    """
    Tzdata: automatic checking for time zone data updates is disabled.

    #{disabled_reason_text(reason)}

    The currently loaded tz release (#{Tzdata.ReleaseReader.release_version()}) will be used.
    To silence this warning, set `config :tzdata, :autoupdate, :disabled`.
    """
  end

  defp disabled_reason_text(:otp_too_old) do
    """
    This Erlang/OTP version (#{otp_version()}) is too old for Tzdata's built-in
    HTTP client (:httpc) to verify TLS certificates. Upgrade to Erlang/OTP
    #{@recommended_otp_version} or newer to enable automatic updates.\
    """
  end

  defp disabled_reason_text(:no_cacerts) do
    """
    Tzdata's built-in HTTP client (:httpc) could not load any OS-trusted CA
    certificates via :public_key.cacerts_get/0 on this Erlang/OTP version
    (#{otp_version()}), so it cannot verify TLS certificates. Make sure the
    operating system's CA certificates are installed, and use Erlang/OTP
    #{@recommended_otp_version} or newer.\
    """
  end

  defp disabled_reason_text({:http_client_not_available, client}) do
    """
    The configured HTTP client #{inspect(client)} (config :tzdata, :http_client)
    is not available. Note that Hackney support (Tzdata.HTTPClient.Hackney) was
    removed in Tzdata 1.3.0. Remove the :http_client setting to use the
    built-in :httpc client (Erlang/OTP #{@recommended_otp_version} or newer is
    recommended).\
    """
  end

  defp otp_version do
    major = :erlang.system_info(:otp_release) |> to_string()
    file = Path.join([:code.root_dir(), "releases", major, "OTP_VERSION"])

    case File.read(file) do
      {:ok, version} -> String.trim(version)
      _ -> major
    end
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
    Logger.debug("Tzdata polling for update. (#{DataLoader.http_client_name()})")

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
