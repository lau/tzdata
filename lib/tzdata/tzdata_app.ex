defmodule Tzdata.App do
  use Application

  def start(_type, _args) do
    Tzdata.EtsHolderSupervisor.start_link
    Tzdata.ReleaseUpdaterSupervisor.start_link
  end
end
