defmodule Tzdata.LeapSecParser2 do
  import Tzdata.Util
  @moduledoc false
  # Parsing of the leap second file `leapseconds`

  @file_name "leapseconds"
  def read_file(dir_prepend \\ "source_data", file_name \\ @file_name) do
    File.stream!("#{dir_prepend}/#{file_name}")
    |> process_file
  end

  defp process_file(file_stream) do
    file_stream
    |> filter_comment_lines
    |> filter_empty_lines
    |> Stream.map(&(strip_comment(&1))) # Strip comments at line end. Like this comment.
    |> Stream.map(&(process_line(&1)))
  end

  @line_regex ~r/Leap[\s]+(?<year>[^\s]+)[\s]+(?<month>[^\s]+)[\s]+(?<day>[^\s]+)[\s]+(?<hour>[\d]+):(?<min>[\d]+):(?<sec>[\d]+)[\s]+(?<correction>[^\s])[\s]+(?<rolling_or_stationary>[^\s])/
  defp process_line(line) do
    map = Regex.named_captures(@line_regex, line)
    month = month_number_for_month_name(map["month"])
    %{ datetime: {{to_int(map["year"]),month, to_int(map["day"]) },
                  {to_int(map["hour"]), to_int(map["min"]), to_int(map["sec"])}},
       is_utc: map["rolling_or_stationary"]=="S",
       is_additive: map["correction"] == "+"
    }
  end
end
