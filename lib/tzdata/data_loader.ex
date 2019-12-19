defmodule Tzdata.DataLoader do
  @moduledoc false

  require Logger
  @compile :nowarn_deprecated_function
  # Can poll for newest version of tz data and can download
  # and extract it.
  @download_url "https://data.iana.org/time-zones/tzdata-latest.tar.gz"
  def download_new(url \\ @download_url) do
    Logger.debug("Tzdata downloading new data from #{url}")
    set_latest_remote_poll_date()
    {:ok, {200, headers, body}} = http_client().get(url, [], follow_redirect: true)
    content_length = byte_size(body)
    {:ok, last_modified} = last_modified_from_headers(headers)

    new_dir_name =
      "#{data_dir()}/tmp_downloads/#{content_length}_#{:random.uniform(100_000_000)}/"

    File.mkdir_p!(new_dir_name)
    target_filename = "#{new_dir_name}latest.tar.gz"
    File.write!(target_filename, body)
    extract(target_filename, new_dir_name)
    release_version = release_version_for_dir(new_dir_name)
    Logger.debug("Tzdata data downloaded. Release version #{release_version}.")
    {:ok, content_length, release_version, new_dir_name, last_modified}
  end

  defp extract(filename, target_dir) do
    :erl_tar.extract(filename, [:compressed, {:cwd, target_dir}])
    # remove tar.gz file after extraction
    File.rm!(filename)
  end

  def release_version_for_dir(dir_name) do
    [only_line_in_file] =
      "#{dir_name}/version"
      |> File.stream!()
      |> Enum.to_list()

    only_line_in_file |> String.replace(~r/\s/, "")
  end

  def last_modified_of_latest_available(url \\ @download_url) do
    set_latest_remote_poll_date()

    case http_client().head(url, [], []) do
      {:ok, {200, headers}} ->
        last_modified_from_headers(headers)

      _ ->
        {:error, :did_not_get_ok_response}
    end
  end

  def latest_file_size(url \\ @download_url) do
    set_latest_remote_poll_date()

    case latest_file_size_by_head(url) do
      {:ok, size} ->
        {:ok, size}

      _ ->
        Logger.debug("Could not get latest tzdata file size by HEAD request. Trying GET request.")
        latest_file_size_by_get(url)
    end
  end

  defp latest_file_size_by_get(url) do
    case http_client().get(url, [], []) do
      {:ok, {200, _headers, body}} ->
        {:ok, byte_size(body)}

      _ ->
        {:error, :did_not_get_ok_response}
    end
  end

  defp latest_file_size_by_head(url) do
    http_client().head(url, [], [])
    |> do_latest_file_size_by_head
  end

  defp do_latest_file_size_by_head({:error, error}), do: {:error, error}

  defp do_latest_file_size_by_head({_tag, resp_code, _headers}) when resp_code != 200,
    do: {:error, :did_not_get_ok_response}

  defp do_latest_file_size_by_head({_tag, _resp_code, headers}) do
    headers
    |> content_length_from_headers
  end

  defp content_length_from_headers(headers) do
    case value_from_headers(headers, "Content-Length") do
      {:ok, content_length} -> {:ok, content_length |> String.to_integer()}
      {:error, reason} -> {:error, reason}
    end
  end

  defp last_modified_from_headers(headers) do
    value_from_headers(headers, "Last-Modified")
  end

  defp value_from_headers(headers, key) do
    header =
      headers
      |> Enum.filter(fn {k, _v} -> String.downcase(k) == String.downcase(key) end)
      |> List.first()

    case header do
      nil -> {:error, :not_found}
      {_, value} -> {:ok, value}
      _ -> {:error, :unexpected_headers}
    end
  end

  def set_latest_remote_poll_date do
    {y, m, d} = current_date_utc()
    File.write!(remote_poll_file_name(), "#{y}-#{m}-#{d}")
  end

  def latest_remote_poll_date do
    latest_remote_poll_file_exists?() |> do_latest_remote_poll_date
  end

  defp do_latest_remote_poll_date(_file_exists = true) do
    File.stream!(remote_poll_file_name())
    |> Enum.to_list()
    |> return_value_for_file_list
  end

  defp do_latest_remote_poll_date(_file_exists = false), do: {:unknown, nil}

  defp return_value_for_file_list([]), do: {:unknown, nil}

  defp return_value_for_file_list([one_line]) do
    date =
      one_line
      |> String.split("-")
      |> Enum.map(&(Integer.parse(&1) |> elem(0)))
      |> List.to_tuple()

    {:ok, date}
  end

  defp return_value_for_file_list(_) do
    raise "latest_remote_poll.txt contains more than 1 line. It should contain exactly 1 line. Remove the file latest_remote_poll.txt in order to resolve the problem."
  end

  defp latest_remote_poll_file_exists?, do: File.exists?(remote_poll_file_name())

  defp current_date_utc, do: :calendar.universal_time() |> elem(0)

  def days_since_last_remote_poll do
    {tag, date} = latest_remote_poll_date()

    case tag do
      :ok ->
        days_today = :calendar.date_to_gregorian_days(current_date_utc())
        days_latest = :calendar.date_to_gregorian_days(date)
        {:ok, days_today - days_latest}

      _ ->
        {tag, date}
    end
  end

  def remote_poll_file_name do
    data_dir() <> "/latest_remote_poll.txt"
  end

  defp data_dir, do: Tzdata.Util.data_dir()

  defp http_client() do
    Application.get_env(:tzdata, :http_client, Tzdata.HTTPClient.Hackney)
  end
end
