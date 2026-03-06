defmodule SppaWeb.UserLive.SettingsTest do
  use SppaWeb.ConnCase, async: true

  alias Sppa.Accounts
  import Phoenix.LiveViewTest
  import Sppa.AccountsFixtures

  describe "Settings route /users/settings" do
    test "redirects to dashboard when logged in", %{conn: conn} do
      {:error, redirect} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/settings")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/dashboard"
    end

    test "redirects to log-in when not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{conn: log_in_user(conn, user), token: token, email: email, user: user}
    end

    test "updates the user email once and redirects to dashboard", %{
      conn: conn,
      user: user,
      token: token,
      email: email
    } do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/dashboard"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)
    end

    test "shows error when confirm token is reused", %{conn: conn, token: token} do
      {:error, _} = live(conn, ~p"/users/settings/confirm-email/#{token}")

      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/dashboard"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/oops")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/dashboard"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects to log-in if user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
