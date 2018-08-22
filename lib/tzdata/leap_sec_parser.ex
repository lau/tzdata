defmodule Tzdata.LeapSecParser do
  import Tzdata.Util
  @moduledoc false
  # Parsing of the `leap-seconds.list` file

  @secs_between_year_0_and_unix_epoch 719528*24*3600 # From erlang calendar docs: there are 719528 days between Jan 1, 0 and Jan 1, 1970. Does not include leap seconds
  @ntp_epoch_and_unix_epoch_diff 2208988800

  @file_name "leap-seconds.list"
  def read_file(dir_prepend \\ "source_data", file_name \\ @file_name) do
    File.stream!("#{dir_prepend}#{file_name}")
    |> process_file
  end

  defp process_file(file_stream) do
    file_stream
    |> Stream.map(&(uncomment_expiry_line(&1)))
    |> filter_comment_lines
    |> filter_empty_lines
    |> filter_dummy_line
    |> Stream.map(&(strip_comment(&1))) # Strip comments at line end. Like this comment.
    |> Stream.map(&(process_line(&1)))
    |> Enum.to_list
    |> organize_into_map
  end

  @expiry_line_regex ~r/\#\@[\s]+(?<expiry_timestamp>[\d]+)/
  defp uncomment_expiry_line(line) do
    map = Regex.named_captures(@expiry_line_regex, line)
    if map do
      "#{map["expiry_timestamp"]}"
    else
      line
    end
  end

  @line_regex ~r/(?<ntp_timestamp>[\d]+)[\s]+(?<tai_diff>[^\s]+)/
  defp process_line(line) do
    map = Regex.named_captures(@line_regex, line)
    h_process_line(map, line)
  end
  defp h_process_line(_matches_leap_line_regex = nil, line) do
    # If it's not a normal line we assume it's a line with expiry time
    %{expires_at: line |> to_int |> ntp_to_unix_timestamp
                  |> :calendar.gregorian_seconds_to_datetime }
  end
  defp h_process_line(map, _line) do
    expiry_timestamp = map["ntp_timestamp"]
                       |> to_int
                       |> ntp_to_unix_timestamp

    # We subtract one second from the timestamp
    # This is because we can easily convert to a datetime and then simply
    # change the second part from 59 to 60
    unix_sec_before = expiry_timestamp - 1

    date_time_sec_before = unix_sec_before
      |> :calendar.gregorian_seconds_to_datetime

    # Note: we assume that all leapseconds are additive
    # ie. we add an extra second, we don't skip them.
    # If the earth rotation suddenly changes such that we will have
    # leap seconds that are not additive, this software will have to change to
    # take that into account.
    %{ date_time: advance_datetime_from_59_to_60_sec(date_time_sec_before),
       tai_diff: to_int(map["tai_diff"]) }
  end

  defp advance_datetime_from_59_to_60_sec(datetime) do
    {date, {h, m, 59}} = datetime
    {date, {h, m, 60}}
  end

  defp ntp_to_unix_timestamp(ntp_timestamp) do
    ntp_timestamp + @secs_between_year_0_and_unix_epoch - @ntp_epoch_and_unix_epoch_diff
  end

  # We assume that the head of the list is the element with the expiry timestamp
  defp organize_into_map([expiry_element = %{expires_at: _} | tail]) do
    %{valid_until: expiry_element.expires_at,
      leap_seconds: tail
     }
  end

  # leap-seconds.list has a line that is not really a leap second. It starts with 2272060800
  def filter_dummy_line(stream) do
    Stream.filter(stream, fn x -> !Regex.match?(~r/2272060800.*#/, x) end)
  end
end
