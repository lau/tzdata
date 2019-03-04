defmodule Tzdata.HTTPClient do
  @moduledoc """
  Behaviour for HTTP client used by Tzdata.
  """

  @type status() :: non_neg_integer()

  @type headers() :: [{header_name :: String.t(), header_value :: String.t()}]

  @type body :: binary()

  @type option :: {:follow_redirect, boolean}

  @callback get(url :: String.t(), headers, [option]) ::
              {:ok, {status, headers, body}} | {:error, term()}

  @callback head(url :: String.t(), headers, [option]) ::
              {:ok, {status, headers}} | {:error, term()}
end
