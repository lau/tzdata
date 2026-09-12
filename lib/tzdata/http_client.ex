defmodule Tzdata.HTTPClient do
  @moduledoc false && """
  Behaviour for HTTP client used by Tzdata.

  See "HTTP Client" section in README.md for more information.
  """

  @type status() :: non_neg_integer()

  @type headers() :: [{header_name :: String.t(), header_value :: String.t()}]

  @type body() :: binary()

  @type option() :: {:follow_redirect, boolean}

  @callback get(url :: String.t(), headers(), options :: [option]) ::
              {:ok, {status(), headers(), body()}} | {:error, term()}

  @callback head(url :: String.t(), headers(), options :: [option]) ::
              {:ok, {status(), headers()}} | {:error, term()}

  @doc false
  # Picks a HTTP client when the user has not configured one explicitly.
  # Prefers the dependency-free `:httpc`-based client when it can verify
  # certificates on the running Erlang/OTP version, falls back to Hackney
  # when that's not the case but Hackney is available, and otherwise
  # defaults back to the `:httpc`-based client (which will log a warning
  # and skip automatic updates rather than download without verification).
  def default do
    cond do
      Tzdata.HTTPClient.Httpc.safe_to_use?() -> Tzdata.HTTPClient.Httpc
      Code.ensure_loaded?(:hackney) -> Tzdata.HTTPClient.Hackney
      true -> Tzdata.HTTPClient.Httpc
    end
  end
end
