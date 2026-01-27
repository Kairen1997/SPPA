defmodule Sppa.IntegrationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Sppa.Integrations` context.
  """

  @doc """
  Generate a external_document.
  """
  def external_document_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        :"\\" => "some \\"
      })

    {:ok, external_document} = Sppa.Integrations.create_external_document(scope, attrs)
    external_document
  end
end
