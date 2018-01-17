defmodule Tzdata.BasicDataMap do
  @moduledoc false

  alias Tzdata.Parser
  alias Tzdata.ParserOrganizer, as: Organizer
  @file_names ~w(africa antarctica asia australasia backward etcetera europe northamerica southamerica)s
  def from_files_in_dir(dir_name) do
    Enum.map(@file_names, fn file_name -> {String.to_atom(file_name), Parser.read_file(file_name, dir_name)} end)
    |> make_map
  end

  def make_map(all_files_read) do
    all_files_flattened = all_files_read |> Enum.map(fn {_name, read_file} -> read_file end) |> List.flatten
    rules = Organizer.rules(all_files_flattened)
    zones = Organizer.zones(all_files_flattened)
    links = Organizer.links(all_files_flattened)
    zone_list = Organizer.zone_list(all_files_flattened)
    link_list = Organizer.link_list(all_files_flattened)
    zone_and_link_list = Organizer.zone_and_link_list(all_files_flattened)

    by_group = all_files_read
    |> Enum.map(fn {name, file_read} -> {name, Organizer.zone_and_link_list(file_read)} end)
    |> Enum.into(Map.new)
    {:ok,
      %{rules: rules,
      zones: zones,
      links: links,
      zone_list: zone_list,
      link_list: link_list,
      zone_and_link_list: zone_and_link_list,
      by_group: by_group,
      }
    }
  end
end
