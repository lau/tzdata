defmodule Tzdata.ReleaseUpdaterTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Tzdata.ReleaseUpdater

  setup do
    previous = Application.get_env(:tzdata, :http_client)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:tzdata, :http_client)
        client -> Application.put_env(:tzdata, :http_client, client)
      end
    end)
  end

  describe "update_check_status/0" do
    test "without a configured client, depends on whether Httpc can verify certificates" do
      Application.delete_env(:tzdata, :http_client)

      case Tzdata.HTTPClient.Httpc.unsafe_reason() do
        nil -> assert ReleaseUpdater.update_check_status() == :ok
        reason -> assert ReleaseUpdater.update_check_status() == {:disabled, reason}
      end
    end

    test "is disabled when the configured client module is not available" do
      Application.put_env(:tzdata, :http_client, Tzdata.HTTPClient.Hackney)

      assert ReleaseUpdater.update_check_status() ==
               {:disabled, {:http_client_not_available, Tzdata.HTTPClient.Hackney}}
    end

    test "is enabled for an available custom client" do
      Application.put_env(:tzdata, :http_client, __MODULE__)

      assert ReleaseUpdater.update_check_status() == :ok
    end
  end

  describe "disabled_message/1" do
    test "recommends a recent Erlang/OTP version when OTP is too old" do
      message = ReleaseUpdater.disabled_message(:otp_too_old)

      assert message =~ "automatic checking for time zone data updates is disabled"
      assert message =~ "too old"
      assert message =~ "27.3.4.19 or newer"
      assert message =~ Tzdata.tzdata_version()
    end

    test "mentions that Hackney support was removed for an unavailable client" do
      message =
        ReleaseUpdater.disabled_message({:http_client_not_available, Tzdata.HTTPClient.Hackney})

      assert message =~ "Tzdata.HTTPClient.Hackney"
      assert message =~ "removed in Tzdata 1.3.0"
    end
  end

  test "the updater logs a warning and stays idle when update checks are disabled" do
    Application.put_env(:tzdata, :http_client, Tzdata.HTTPClient.Hackney)

    log =
      capture_log(fn ->
        assert {:ok, []} = ReleaseUpdater.init([])
      end)

    assert log =~ "automatic checking for time zone data updates is disabled"
    refute_receive :check_if_time_to_update, 3500
  end
end
