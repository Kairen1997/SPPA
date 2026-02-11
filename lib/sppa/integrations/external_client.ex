defmodule Sppa.Integrations.ExternalClient do
  require Logger

  @external_url "http://10.71.67.140:4000/api/requests?status=Diluluskan"

  defp requests_url do
    @external_url
  end

  # Keys the external API might use to wrap the list of requests (try in order)
  @response_list_keys ["data", "requests", "permohonan", "results"]

  # Public API used by the worker
  def fetch_documents do
    url = requests_url()
    Logger.info("Fetching documents from: #{url}")

    do_fetch(url, 3)
  end

  defp do_fetch(url, attempts_left) when attempts_left > 0 do
    opts = [
      receive_timeout: 120_000,
      retry: :transient,
      retry_delay: 2_000
    ]

    case Req.get(url, opts) do
      {:ok, %{status: 200, body: body}} ->
        case normalize_body_to_list(body) do
          {:ok, list} ->
            Logger.info("Successfully got #{length(list)} documents from external API")
            {:ok, list}

          {:error, reason} ->
            Logger.error("Failed to normalize API response: #{inspect(reason)}")
            {:error, reason}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("HTTP request failed with status #{status}")
        log_body_sample(body)
        {:error, {:http_error, status, body}}

      {:error, %{reason: :timeout} = err} ->
        Logger.error(
          "Req timeout when fetching external documents (attempts_left=#{attempts_left - 1}): #{inspect(err)}"
        )
        Process.sleep(2_000)
        do_fetch(url, attempts_left - 1)

      {:error, err} ->
        Logger.error("Req error when fetching external documents: #{inspect(err)}")
        {:error, {:http_error, err}}
    end
  end

  defp do_fetch(_url, 0) do
    Logger.error("Exhausted all retries when fetching external documents")
    {:error, {:http_error, :timeout}}
  end

  # Req may return body already decoded (map/list) when Content-Type is application/json.
  # Otherwise body is binary and we must decode with Jason.
  defp normalize_body_to_list(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> unwrap_to_list(decoded)
      {:error, reason} ->
        Logger.error("Failed to decode JSON: #{inspect(reason)}")
        {:error, {:json_decode_error, reason}}
    end
  end

  defp normalize_body_to_list(body) when is_list(body), do: {:ok, body}
  defp normalize_body_to_list(body) when is_map(body), do: unwrap_to_list(body)

  defp normalize_body_to_list(other) do
    Logger.error("Unexpected response body type: #{inspect(other)}")
    {:error, :invalid_body_type}
  end

  # Unwrap common API response shapes to a list of items.
  defp unwrap_to_list(list) when is_list(list), do: {:ok, list}

  defp unwrap_to_list(map) when is_map(map) do
    found =
      Enum.find_value(@response_list_keys, fn key ->
        case map[key] do
          list when is_list(list) -> list
          _ -> nil
        end
      end)

    if found do
      {:ok, found}
    else
      # Single object wrapped as response (e.g. %{"request" => %{...}})
      single = map["request"] || map["request_id"]
      if is_map(single), do: {:ok, [single]}, else: {:ok, [map]}
    end
  end

  defp log_body_sample(body) when is_binary(body) do
    Logger.error("Response body (first 500 chars): #{String.slice(body, 0, 500)}")
  end

  defp log_body_sample(body) when is_map(body) or is_list(body) do
    Logger.error("Response body: #{inspect(body, limit: 500)}")
  end

  defp log_body_sample(other), do: Logger.error("Response body: #{inspect(other)}")
end
