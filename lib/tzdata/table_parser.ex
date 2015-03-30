defmodule Tzdata.TableParser do
  @moduledoc false
  # Parsing of the table file zone1970.tab

  @file_name "zone1970.tab"
  def read_file(dir_prepend \\ "source_data", file_name \\ @file_name) do
    File.stream!("#{dir_prepend}/#{file_name}")
    |> process_file
  end

  def process_file(file_stream) do
    file_stream
    |> filter_comment_lines
    |> filter_empty_lines
    |> Stream.map(&(strip_comment(&1))) # Strip comments at line end. Like this comment.
    |> Stream.map(&(process_line(&1)))
  end

  @line_regex ~r/(?<country_codes>[^\s]+)[\s]+(?<latlong>[^\s]+)[\s]+(?<timezone>[^\s]+)[\s]+(?<comments>[^\n]+)?/
  defp process_line(line) do
    map = Regex.named_captures(@line_regex, line)
    map = %{map | "country_codes" => split_country_codes(map["country_codes"]) }
    map
  end

  defp split_country_codes(string) do
    String.split(string, ",")
  end

  defp strip_comment(line), do: Regex.replace(~r/[\s]*#.+/, line, "")
  defp filter_comment_lines(input) do
    Stream.filter(input, fn x -> !Regex.match?(~r/^[\s]*#/, x) end)
  end
  defp filter_empty_lines(input) do
    Stream.filter(input, fn x -> !Regex.match?(~r/^\n$/, x) end)
  end
end
