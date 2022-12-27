ExUnit.start()

# Allow testing the read-only filesystem code with
# `mix test --include read_only_fs`
if :read_only_fs in ExUnit.configuration()[:include] do
  Application.put_env(:tzdata, :read_only_fs?, true)
end
