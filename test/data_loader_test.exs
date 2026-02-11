defmodule Tzdata.DataLoaderTest do
  use ExUnit.Case, async: true

  alias Tzdata.DataLoader

  setup do
    sham = Sham.start()
    original_client = Application.get_env(:tzdata, :http_client)

    Application.put_env(:tzdata, :http_client, Tzdata.HTTPClient.Hackney)

    on_exit(fn ->
      if original_client do
        Application.put_env(:tzdata, :http_client, original_client)
      else
        Application.delete_env(:tzdata, :http_client)
      end
    end)

    {:ok, sham: sham}
  end

  describe "latest_file_size/1" do
    test "gets file size from HEAD request", %{sham: sham} do
      url = "http://localhost:#{sham.port}/test.tar.gz"

      Sham.expect(sham, "HEAD", "/test.tar.gz", fn conn ->
        # For HEAD requests, include a body matching the content-length
        # (in reality, HEAD responses don't include the body, but for testing
        # with Sham, Plug will calculate content-length from the body)
        body = String.duplicate("x", 12345)

        conn
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:ok, 12345} = DataLoader.latest_file_size(url)
    end

    test "falls back to GET when HEAD fails", %{sham: sham} do
      url = "http://localhost:#{sham.port}/fallback.tar.gz"

      Sham.expect(sham, "HEAD", "/fallback.tar.gz", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      Sham.expect(sham, "GET", "/fallback.tar.gz", fn conn ->
        Plug.Conn.resp(conn, 200, "test body content")
      end)

      assert {:ok, 17} = DataLoader.latest_file_size(url)
    end
  end

  describe "last_modified_of_latest_available/1" do
    test "gets last modified date from HEAD request", %{sham: sham} do
      url = "http://localhost:#{sham.port}/modified.tar.gz"

      Sham.expect(sham, "HEAD", "/modified.tar.gz", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("last-modified", "Wed, 21 Oct 2015 07:28:00 GMT")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, "Wed, 21 Oct 2015 07:28:00 GMT"} =
               DataLoader.last_modified_of_latest_available(url)
    end
  end
end
