defmodule Sppa.Integrations.ExternalClient do
  require Logger

  @external_url "http://10.71.68.215:4000/api/requests?status=Diluluskan"

  # Public API used by the worker
  def fetch_documents do
    headers = [{"accept", "application/json"}]

    Logger.info("Fetching documents from: #{@external_url}")

    # More robust fetch with retries and longer timeouts to reduce :timeout errors
    do_fetch(@external_url, headers, 3)
  end

  # Internal helper with simple retry logic
  defp do_fetch(url, headers, attempts_left) when attempts_left > 0 do
    # Use longer timeouts since the external system can be slow
    opts = [timeout: 120_000, recv_timeout: 120_000]

    case HTTPoison.get(url, headers, opts) do
      {:ok, %{status_code: 200, body: body}} ->
        Logger.info("Received response with body length: #{String.length(body)}")


        case Jason.decode(body) do
          {:ok, decoded} ->
            Logger.info(
              "Successfully decoded JSON. Type: #{inspect(is_list(decoded))}, Count: #{if is_list(decoded), do: length(decoded), else: "N/A"}"
            )

            Logger.info(
              "Successfully decoded JSON. Type: #{inspect(is_list(decoded))}, Count: #{if is_list(decoded), do: length(decoded), else: "N/A"}"
            )

            {:ok, decoded}


          {:error, reason} ->
            Logger.error("Failed to decode JSON: #{inspect(reason)}")
            Logger.error("Response body (first 500 chars): #{String.slice(body, 0, 500)}")
            {:error, {:json_decode_error, reason}}
        end

      {:ok, %{status_code: status_code, body: body}} ->
        Logger.error("HTTP request failed with status #{status_code}")
        Logger.error("Response body (first 500 chars): #{String.slice(body, 0, 500)}")
        {:error, {:http_error, status_code, body}}

      {:error, %HTTPoison.Error{reason: :timeout} = err} ->
        Logger.error(
          "HTTPoison timeout when fetching external documents (attempts_left=#{attempts_left - 1}): #{inspect(err)}"
        )

        # Simple backoff before retrying
        Process.sleep(2_000)
        do_fetch(url, headers, attempts_left - 1)

      {:error, %HTTPoison.Error{reason: reason} = err} ->
        Logger.error("HTTPoison error when fetching external documents: #{inspect(err)}")
        {:error, {:http_error, reason}}
    end
  end

  defp do_fetch(_url, _headers, 0) do
    Logger.error("Exhausted all retries when fetching external documents")
    {:error, {:http_error, :timeout}}
  end
end
