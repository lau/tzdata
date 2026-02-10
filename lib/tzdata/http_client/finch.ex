defmodule Tzdata.HTTPClient.Finch do
  @moduledoc false

  @behaviour Tzdata.HTTPClient

  if Code.ensure_loaded?(Finch) do
    @impl true
    def get(url, headers, options) do
      follow_redirect = Keyword.get(options, :follow_redirect, false)
      max_redirects = Keyword.get(options, :max_redirects, 10)
      # Store base URL for resolving relative redirects
      options_with_base = Keyword.put_new(options, :base_url, url)

      request = Finch.build(:get, url, headers)

      case Finch.request(request, Tzdata.Finch, receive_timeout: 30_000) do
        {:ok, %Finch.Response{status: status, headers: response_headers, body: body}}
        when status in [301, 302, 307, 308] ->
          if follow_redirect do
            handle_redirect(status, response_headers, headers, options_with_base, max_redirects)
          else
            {:ok, {status, response_headers, body}}
          end

        {:ok, %Finch.Response{status: status, headers: response_headers, body: body}} ->
          {:ok, {status, response_headers, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end

    @impl true
    def head(url, headers, _options) do
      request = Finch.build(:head, url, headers)

      case Finch.request(request, Tzdata.Finch, receive_timeout: 30_000) do
        {:ok, %Finch.Response{status: status, headers: response_headers}} ->
          {:ok, {status, response_headers}}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp handle_redirect(status, response_headers, original_headers, options, redirects_remaining) do
      cond do
        redirects_remaining <= 0 ->
          {:error, :too_many_redirects}

        true ->
          case List.keyfind(response_headers, "location", 0) do
            {"location", redirect_url} ->
              # Handle relative URLs by converting to absolute
              absolute_url = resolve_redirect_url(redirect_url, options[:base_url])
              updated_options =
                options
                |> Keyword.put(:max_redirects, redirects_remaining - 1)
                |> Keyword.put(:base_url, absolute_url)

              get(absolute_url, original_headers, updated_options)

            nil ->
              {:error, {:redirect_without_location, status}}
          end
      end
    end

    defp resolve_redirect_url(url, base_url) do
      cond do
        String.starts_with?(url, "http://") or String.starts_with?(url, "https://") ->
          url

        base_url != nil ->
          uri = URI.parse(base_url)
          URI.to_string(%{uri | path: url, query: nil, fragment: nil})

        true ->
          url
      end
    end
  else
    @message """
    missing Finch dependency

    Tzdata requires a HTTP client in order to automatically update timezone
    database.

    In order to use the built-in adapter based on Finch HTTP client, add the
    following to your mix.exs dependencies list:

        {:finch, "~> 0.16"}

    See README for more information.
    """

    @impl true
    def get(_url, _headers, _options) do
      raise @message
    end

    @impl true
    def head(_url, _headers, _options) do
      raise @message
    end
  end
end
