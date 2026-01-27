defmodule Sppa.Integrations do
  @moduledoc """
  The Integrations context.
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo

  alias Sppa.Integrations.ExternalDocument
  alias Sppa.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any external_document changes.

  The broadcasted messages match the pattern:

    * {:created, %ExternalDocument{}}
    * {:updated, %ExternalDocument{}}
    * {:deleted, %ExternalDocument{}}

  """
  def store_document(attrs) do
    %ExternalDocument{}
    |> ExternalDocument.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing)
  end

  def download_pdf(url, filename) do
    pdf_dir = Path.join(["priv", "static", "uploads", "pdfs"])
    File.mkdir_p!(pdf_dir)

    path = Path.join(pdf_dir, filename)

    {:ok, %{body: body}} = HTTPoison.get(url)
    File.write!(path, body)

    path
  end

  def subscribe_external_documents(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Sppa.PubSub, "user:#{key}:external_documents")
  end

  defp broadcast_external_document(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(Sppa.PubSub, "user:#{key}:external_documents", message)
  end

  @doc """
  Returns the list of external_documents.

  ## Examples

      iex> list_external_documents(scope)
      [%ExternalDocument{}, ...]

  """
  def list_external_documents(%Scope{} = scope) do
    Repo.all_by(ExternalDocument, user_id: scope.user.id)
  end

  @doc """
  Gets a single external_document.

  Raises `Ecto.NoResultsError` if the External document does not exist.

  ## Examples

      iex> get_external_document!(scope, 123)
      %ExternalDocument{}

      iex> get_external_document!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_external_document!(%Scope{} = scope, id) do
    Repo.get_by!(ExternalDocument, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a external_document.

  ## Examples

      iex> create_external_document(scope, %{field: value})
      {:ok, %ExternalDocument{}}

      iex> create_external_document(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_external_document(%Scope{} = scope, attrs) do
    with {:ok, external_document = %ExternalDocument{}} <-
           %ExternalDocument{}
           |> ExternalDocument.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_external_document(scope, {:created, external_document})
      {:ok, external_document}
    end
  end

  @doc """
  Updates a external_document.

  ## Examples

      iex> update_external_document(scope, external_document, %{field: new_value})
      {:ok, %ExternalDocument{}}

      iex> update_external_document(scope, external_document, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_external_document(%Scope{} = scope, %ExternalDocument{} = external_document, attrs) do
    true = external_document.user_id == scope.user.id

    with {:ok, external_document = %ExternalDocument{}} <-
           external_document
           |> ExternalDocument.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_external_document(scope, {:updated, external_document})
      {:ok, external_document}
    end
  end

  @doc """
  Deletes a external_document.

  ## Examples

      iex> delete_external_document(scope, external_document)
      {:ok, %ExternalDocument{}}

      iex> delete_external_document(scope, external_document)
      {:error, %Ecto.Changeset{}}

  """
  def delete_external_document(%Scope{} = scope, %ExternalDocument{} = external_document) do
    true = external_document.user_id == scope.user.id

    with {:ok, external_document = %ExternalDocument{}} <-
           Repo.delete(external_document) do
      broadcast_external_document(scope, {:deleted, external_document})
      {:ok, external_document}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking external_document changes.

  ## Examples

      iex> change_external_document(scope, external_document)
      %Ecto.Changeset{data: %ExternalDocument{}}

  """
  def change_external_document(%Scope{} = scope, %ExternalDocument{} = external_document, attrs \\ %{}) do
    true = external_document.user_id == scope.user.id

    ExternalDocument.changeset(external_document, attrs, scope)
  end
end
