defmodule Sppa.Workers.ExternalSyncWorker do
  use Oban.Worker, queue: :default

  require Logger

  alias Sppa.Integrations.ExternalClient
  alias Sppa.ApprovedProjects

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting external sync worker...")

    ExternalClient.fetch_documents()
    |> case do
      {:ok, documents} when is_list(documents) ->
        Logger.info("Fetched #{length(documents)} documents from external API")

        sync_count =
          documents
          |> Enum.map(&map_to_approved_project/1)
          |> Enum.with_index(1)
          |> Enum.count(fn {attrs, index} ->
            external_id = attrs["external_application_id"]
            nama_projek = attrs["nama_projek"]

            Logger.info("Processing document #{index}: external_application_id=#{inspect(external_id)}, nama_projek=#{inspect(nama_projek)}")
            Logger.info("Full attributes: #{inspect(attrs)}")

            # Validate required fields before attempting insert
            if is_nil(external_id) or is_nil(nama_projek) or nama_projek == "" do
              Logger.error("Document #{index} missing required fields: external_id=#{inspect(external_id)}, nama_projek=#{inspect(nama_projek)}")
              false
            else
              case ApprovedProjects.create_approved_project(attrs) do
              {:ok, project} when not is_nil(project) ->
                Logger.info("Successfully created approved project: ID=#{project.id}, external_id=#{project.external_application_id}")
                true
              {:ok, nil} ->
                # Duplicate - already exists
                Logger.debug("Skipping duplicate approved project (external_id=#{attrs["external_application_id"]})")
                false
              {:error, changeset} ->
                # Log error but don't fail the job - might be duplicate
                errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
                  Enum.reduce(opts, msg, fn {key, value}, acc ->
                    String.replace(acc, "%{#{key}}", to_string(value))
                  end)
                end)

                if changeset.data.external_application_id do
                  Logger.debug("Skipping duplicate approved project (external_id=#{changeset.data.external_application_id}): #{inspect(errors)}")
                else
                  Logger.warning("Error creating approved project: #{inspect(errors)}")
                  Logger.warning("Attributes were: #{inspect(attrs)}")
                end
                false
              end
            end
          end)

        Logger.info("Synced #{sync_count}/#{length(documents)} approved projects from external API")
        :ok

      {:ok, response} ->
        Logger.error("Unexpected response format from external API. Expected list, got: #{inspect(response)}")
        Logger.error("Response type: #{inspect(is_map(response))}, is_list: #{inspect(is_list(response))}")
        {:error, :invalid_response_format}

      {:error, reason} ->
        Logger.error("Error fetching documents: #{inspect(reason)}")
        Logger.error("Full error details: #{inspect(reason, pretty: true)}")
        {:error, reason}
    end
  end

  # Map external API response to ApprovedProject attributes
  # Based on actual API response structure from http://10.71.67.195:4000/api/requests?status=Diluluskan
  defp map_to_approved_project(document) when is_map(document) do
    # Log the raw document for debugging
    Logger.debug("Mapping document: #{inspect(Map.keys(document))}")

    external_id = get_integer(document, "id")
    nama_projek = get_string(document, "nama_sistem") ||
                  get_string(document, "nama sistem") ||
                  get_string(document, "nama_projek") ||
                  get_string(document, "name") ||
                  ""

    # If nama_projek is still empty, log warning
    if nama_projek == "" do
      Logger.warning("Document with id=#{external_id} has no nama_projek. Available keys: #{inspect(Map.keys(document))}")
    end

    %{
      "external_application_id" => external_id,
      "nama_projek" => nama_projek,
      # API uses "kementerian_jabatan"
      "jabatan" => get_string(document, "kementerian_jabatan") ||
                   get_string(document, "jabatan") ||
                   get_string(document, "department") ||
                   get_string(document, "kementerian"),
      # API uses "emel" for email
      "pengurus_email" => get_string(document, "emel") ||
                          get_string(document, "pengurus_email") ||
                          get_string(document, "email") ||
                          get_string(document, "pengurus_projek_email"),
      # API uses "tarikh_permohonan" for start date
      "tarikh_mula" => parse_date(get_string(document, "tarikh_permohonan") ||
                                   get_string(document, "tarikh_mula") ||
                                   get_string(document, "start_date")),
      "tarikh_jangkaan_siap" => parse_date(get_string(document, "tarikh_jangkaan_siap") ||
                                            get_string(document, "expected_completion_date") ||
                                            get_string(document, "tarikh_siap")),
      "pembangun_sistem" => get_string(document, "pembangun_sistem") ||
                            get_string(document, "developer"),
      # API uses "latarbelakang_sistem" (no underscore between latar and belakang)
      "latar_belakang" => get_string(document, "latarbelakang_sistem") ||
                          get_string(document, "latar_belakang") ||
                          get_string(document, "background"),
      # API uses "objektif_sistem"
      "objektif" => get_string(document, "objektif_sistem") ||
                    get_string(document, "objektif") ||
                    get_string(document, "objective"),
      # API uses "skop_sistem"
      "skop" => get_string(document, "skop_sistem") ||
                get_string(document, "skop") ||
                get_string(document, "scope"),
      "kumpulan_pengguna" => get_string(document, "kumpulan_pengguna") ||
                             get_string(document, "user_group"),
      "implikasi" => get_string(document, "implikasi") ||
                     get_string(document, "implication"),
      # API uses "kertas_kerja_url"
      "kertas_kerja_path" => get_string(document, "kertas_kerja_url") ||
                             get_string(document, "kertas_kerja_path") ||
                             get_string(document, "document_path")
    }
  end

  defp map_to_approved_project(_), do: %{}

  defp get_string(map, key) when is_map(map) do
    case Map.get(map, key) || Map.get(map, to_string(key)) do
      nil -> nil
      value when is_binary(value) -> value
      value -> to_string(value)
    end
  end

  defp get_integer(map, key) when is_map(map) do
    case Map.get(map, key) || Map.get(map, to_string(key)) do
      nil -> nil
      value when is_integer(value) -> value
      value when is_binary(value) ->
        case Integer.parse(value) do
          {int, _} -> int
          :error -> nil
        end
      _ -> nil
    end
  end

  defp parse_date(nil), do: nil
  defp parse_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, date} -> date
      _ ->
        # Try other formats if needed
        nil
    end
  end
  defp parse_date(_), do: nil
end
