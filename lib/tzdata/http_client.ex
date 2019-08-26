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
end
