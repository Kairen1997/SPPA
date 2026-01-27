defmodule Sppa.IntegrationsTest do
  use Sppa.DataCase

  alias Sppa.Integrations

  describe "external_documents" do
    alias Sppa.Integrations.ExternalDocument

    import Sppa.AccountsFixtures, only: [user_scope_fixture: 0]
    import Sppa.IntegrationsFixtures

    @invalid_attrs %{"\\": nil}

    test "list_external_documents/1 returns all scoped external_documents" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      external_document = external_document_fixture(scope)
      other_external_document = external_document_fixture(other_scope)
      assert Integrations.list_external_documents(scope) == [external_document]
      assert Integrations.list_external_documents(other_scope) == [other_external_document]
    end

    test "get_external_document!/2 returns the external_document with given id" do
      scope = user_scope_fixture()
      external_document = external_document_fixture(scope)
      other_scope = user_scope_fixture()
      assert Integrations.get_external_document!(scope, external_document.id) == external_document
      assert_raise Ecto.NoResultsError, fn -> Integrations.get_external_document!(other_scope, external_document.id) end
    end

    test "create_external_document/2 with valid data creates a external_document" do
      valid_attrs = %{"\\": "some \\"}
      scope = user_scope_fixture()

      assert {:ok, %ExternalDocument{} = external_document} = Integrations.create_external_document(scope, valid_attrs)
      assert external_document.\ == "some \\"
      assert external_document.user_id == scope.user.id
    end

    test "create_external_document/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Integrations.create_external_document(scope, @invalid_attrs)
    end

    test "update_external_document/3 with valid data updates the external_document" do
      scope = user_scope_fixture()
      external_document = external_document_fixture(scope)
      update_attrs = %{"\\": "some updated \\"}

      assert {:ok, %ExternalDocument{} = external_document} = Integrations.update_external_document(scope, external_document, update_attrs)
      assert external_document.\ == "some updated \\"
    end

    test "update_external_document/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      external_document = external_document_fixture(scope)

      assert_raise MatchError, fn ->
        Integrations.update_external_document(other_scope, external_document, %{})
      end
    end

    test "update_external_document/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      external_document = external_document_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Integrations.update_external_document(scope, external_document, @invalid_attrs)
      assert external_document == Integrations.get_external_document!(scope, external_document.id)
    end

    test "delete_external_document/2 deletes the external_document" do
      scope = user_scope_fixture()
      external_document = external_document_fixture(scope)
      assert {:ok, %ExternalDocument{}} = Integrations.delete_external_document(scope, external_document)
      assert_raise Ecto.NoResultsError, fn -> Integrations.get_external_document!(scope, external_document.id) end
    end

    test "delete_external_document/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      external_document = external_document_fixture(scope)
      assert_raise MatchError, fn -> Integrations.delete_external_document(other_scope, external_document) end
    end

    test "change_external_document/2 returns a external_document changeset" do
      scope = user_scope_fixture()
      external_document = external_document_fixture(scope)
      assert %Ecto.Changeset{} = Integrations.change_external_document(scope, external_document)
    end
  end
end
