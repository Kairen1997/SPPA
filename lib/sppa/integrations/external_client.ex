defmodule Sppa.Integrations.ExternalClient do
  require Logger

  @external_url "http://10.71.67.195:4000/api/requests?status=Diluluskan"

  def fetch_documents do
    headers = [{"accept", "application/json"}]

    Logger.info("Fetching documents from: #{@external_url}")

    case HTTPoison.get(@external_url, headers, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %{status_code: 200, body: body}} ->
        Logger.info("Received response with body length: #{String.length(body)}")
        case Jason.decode(body) do
          {:ok, decoded} ->
            Logger.info("Successfully decoded JSON. Type: #{inspect(is_list(decoded))}, Count: #{if is_list(decoded), do: length(decoded), else: "N/A"}")
            {:ok, decoded}
          {:error, reason} ->
            Logger.error("Failed to decode JSON: #{inspect(reason)}")
            Logger.error("Response body: #{String.slice(body, 0, 500)}")
            {:error, {:json_decode_error, reason}}
        end

      {:ok, %{status_code: status_code, body: body}} ->
        Logger.error("HTTP request failed with status #{status_code}")
        Logger.error("Response body: #{String.slice(body, 0, 500)}")
        {:error, {:http_error, status_code, body}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTPoison error: #{inspect(reason)}")
        {:error, {:http_error, reason}}

      {:error, reason} ->
        Logger.error("Unknown error: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
