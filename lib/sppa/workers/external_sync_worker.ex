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

            Logger.info(
              "Processing document #{index}: external_application_id=#{inspect(external_id)}, nama_projek=#{inspect(nama_projek)}"
            )

            Logger.info("Full attributes: #{inspect(attrs)}")

            # Validate required fields before attempting insert
            if is_nil(external_id) or is_nil(nama_projek) or nama_projek == "" do
              Logger.error(
                "Document #{index} missing required fields: external_id=#{inspect(external_id)}, nama_projek=#{inspect(nama_projek)}"
              )

              false
            else
              case ApprovedProjects.create_approved_project(attrs) do
                {:ok, project} when not is_nil(project) ->
                  Logger.info(
                    "Successfully created approved project: ID=#{project.id}, external_id=#{project.external_application_id}"
                  )

                  true

                {:ok, nil} ->
                  # Duplicate - already exists
                  Logger.debug(
                    "Skipping duplicate approved project (external_id=#{attrs["external_application_id"]})"
                  )

                  false

                {:error, changeset} ->
                  # Log error but don't fail the job - might be duplicate
                  errors =
                    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
                      Enum.reduce(opts, msg, fn {key, value}, acc ->
                        String.replace(acc, "%{#{key}}", to_string(value))
                      end)
                    end)

                  if changeset.data.external_application_id do
                    Logger.debug(
                      "Skipping duplicate approved project (external_id=#{changeset.data.external_application_id}): #{inspect(errors)}"
                    )
                  else
                    Logger.warning("Error creating approved project: #{inspect(errors)}")
                    Logger.warning("Attributes were: #{inspect(attrs)}")
                  end

                  false
              end
            end
          end)

        Logger.info(
          "Synced #{sync_count}/#{length(documents)} approved projects from external API"
        )

        :ok

      {:ok, response} ->
        Logger.error(
          "Unexpected response format from external API. Expected list, got: #{inspect(response)}"
        )

        Logger.error(
          "Response type: #{inspect(is_map(response))}, is_list: #{inspect(is_list(response))}"
        )

        {:error, :invalid_response_format}

      {:error, reason} ->
        Logger.error("Error fetching documents: #{inspect(reason)}")
        Logger.error("Full error details: #{inspect(reason, pretty: true)}")
        {:error, reason}
    end
  end

  # Map external API response to ApprovedProject attributes.
  # API returns a list of objects with: id, nama_sistem, emel, kementerian_jabatan,
  # tarikh_permohonan, latarbelakang_sistem, objektif_sistem, skop_sistem,
  # kumpulan_pengguna, implikasi, kertas_kerja_url, updated_at; optional nested pemohon.
  defp map_to_approved_project(document) when is_map(document) do
    Logger.debug("Mapping document: #{inspect(Map.keys(document))}")

    external_id = get_integer(document, "id")

    nama_projek =
      get_string(document, "nama_sistem") ||
        get_string(document, "nama sistem") ||
        get_string(document, "nama_projek") ||
        get_string(document, "name") ||
        ""

    if nama_projek == "" do
      Logger.warning(
        "Document with id=#{external_id} has no nama_projek. Available keys: #{inspect(Map.keys(document))}"
      )
    end

    attrs = %{
      "external_application_id" => external_id,
      "nama_projek" => nama_projek,
      "jabatan" =>
        get_string(document, "kementerian_jabatan") ||
          get_string(document, "jabatan") ||
          get_string(document, "department") ||
          get_string(document, "kementerian"),
      "pengurus_email" =>
        get_string(document, "emel") ||
          get_nested_string(document, "pemohon", "emel") ||
          get_string(document, "pengurus_email") ||
          get_string(document, "email") ||
          get_string(document, "pengurus_projek_email"),
      # API uses "tarikh_permohonan" for start date
      "tarikh_mula" =>
        parse_date(
          get_string(document, "tarikh_permohonan") ||
            get_string(document, "tarikh_mula") ||
            get_string(document, "start_date")
        ),
      "tarikh_jangkaan_siap" =>
        parse_date(
          get_string(document, "tarikh_jangkaan_siap") ||
            get_string(document, "expected_completion_date") ||
            get_string(document, "tarikh_siap") ||
            get_first_in_list(document, "pengurusan_pelulus", "tarikh_kelulusan")
        ),
      "pembangun_sistem" =>
        get_string(document, "pembangun_sistem") ||
          get_string(document, "developer"),
      # API uses "latarbelakang_sistem" (no underscore between latar and belakang)
      "latar_belakang" =>
        get_string(document, "latarbelakang_sistem") ||
          get_string(document, "latar_belakang") ||
          get_string(document, "background"),
      # API uses "objektif_sistem"
      "objektif" =>
        get_string(document, "objektif_sistem") ||
          get_string(document, "objektif") ||
          get_string(document, "objective"),
      # API uses "skop_sistem"
      "skop" =>
        get_string(document, "skop_sistem") ||
          get_string(document, "skop") ||
          get_string(document, "scope"),
      "kumpulan_pengguna" =>
        get_string(document, "kumpulan_pengguna") ||
          get_string(document, "user_group"),
      "implikasi" =>
        get_string(document, "implikasi") ||
          get_string(document, "implication"),
      # Track external updated_at so we can order the list like the API
      "external_updated_at" =>
        parse_datetime(
          get_string(document, "updated_at") ||
            get_string(document, "updatedAt") ||
            get_string(document, "tarikh_kemaskini") ||
            get_string(document, "tarikh_kemaskinian")
        ),
      # API uses "kertas_kerja_url"
      # Some records may use alternative keys – try several options
      "kertas_kerja_path" =>
        get_string(document, "kertas_kerja_url") ||
          get_string(document, "kertas_kerja_path") ||
          get_string(document, "document_path") ||
          get_string(document, "kertas_kerja") ||
          get_string(document, "kertas_kerja_pdf") ||
          get_string(document, "file_url") ||
          get_string(document, "file")
    }

    # Extra logging to help diagnose missing/invalid document URLs
    case Map.get(attrs, "kertas_kerja_path") do
      nil ->
        Logger.debug(
          "No kertas_kerja_path for external id=#{external_id}. Available keys: #{inspect(Map.keys(document))}"
        )

      "" ->
        Logger.debug(
          "Empty kertas_kerja_path for external id=#{external_id}. Raw value: #{inspect(document["kertas_kerja_url"] || document["kertas_kerja_path"] || document["document_path"])}"
        )

      _ ->
        :ok
    end

    attrs
  end

  defp map_to_approved_project(_), do: %{}

  defp get_string(map, key) when is_map(map) do
    case Map.get(map, key) || Map.get(map, to_string(key)) do
      nil -> nil
      value when is_binary(value) -> value
      value -> to_string(value)
    end
  end

  defp get_nested_string(map, parent_key, child_key) when is_map(map) do
    parent = Map.get(map, parent_key) || Map.get(map, to_string(parent_key))
    if is_map(parent), do: get_string(parent, child_key), else: nil
  end

  defp get_first_in_list(map, list_key, item_key) when is_map(map) do
    list = Map.get(map, list_key) || Map.get(map, to_string(list_key))

    case is_list(list) && List.first(list) do
      first when is_map(first) -> get_string(first, item_key)
      _ -> nil
    end
  end

  defp get_integer(map, key) when is_map(map) do
    case Map.get(map, key) || Map.get(map, to_string(key)) do
      nil ->
        nil

      value when is_integer(value) ->
        value

      value when is_binary(value) ->
        case Integer.parse(value) do
          {int, _} -> int
          :error -> nil
        end

      _ ->
        nil
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, date} ->
        date

      _ ->
        # Try other formats if needed
        nil
    end
  end

  # Parse external updated_at (ISO8601) into a DateTime we can store
  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} ->
        # Truncate to seconds to match :utc_datetime precision
        DateTime.truncate(dt, :second)

      _ ->
        nil
    end
  end
end
