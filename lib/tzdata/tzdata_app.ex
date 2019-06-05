defmodule Tzdata.App do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(Tzdata.EtsHolder, [])
    ]
    children = case Application.fetch_env(:tzdata, :autoupdate) do
      {:ok, :enabled} -> children ++ [worker(Tzdata.ReleaseUpdater, [])]
      {:ok, :disabled} -> children
    end

    {:ok, pid} = Supervisor.start_link(children, strategy: :one_for_one)

    # Make zone atoms exist so that when to_existing_atom is called, all of the zones exist
    Tzdata.zone_list |> Enum.map(&(&1 |> String.to_atom))

    {:ok, pid}
  end
end
