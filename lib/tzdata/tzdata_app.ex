defmodule Tzdata.App do
  @moduledoc false

  use Application

  def start(_type, _args) do
    {:ok, pid} = Supervisor.start_link(children(), strategy: :one_for_one)

    # Make zone atoms exist so that when to_existing_atom is called, all of the zones exist
    Tzdata.zone_list |> Enum.map(&(&1 |> String.to_atom))

    {:ok, pid}
  end

  defp children do
    case Application.fetch_env(:tzdata, :autoupdate) do
      {:ok, :enabled} -> [Tzdata.EtsHolder, Tzdata.ReleaseUpdater]
      {:ok, :disabled} -> [Tzdata.EtsHolder]
    end
  end
end
