defmodule Tzdata.App do
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

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
  end
end
