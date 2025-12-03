defmodule SppaWeb.UserSessionController do
  use SppaWeb, :controller

  alias Sppa.Accounts
  alias SppaWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "User confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info)
       when is_binary(token) and byte_size(token) > 0 do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # no_kp + password login
  defp create(conn, %{"user" => %{"no_kp" => no_kp} = user_params}, info)
       when is_binary(no_kp) and byte_size(no_kp) > 0 do
    %{"password" => password} = user_params

    if user = Accounts.get_user_by_no_kp_and_password(no_kp, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the no_kp is registered.
      conn
      |> put_flash(:error, "Invalid No K/P or password")
      |> redirect(to: ~p"/users/log-in")
    end
  end

  # catch-all for invalid login attempts
  defp create(conn, _params, _info) do
    conn
    |> put_flash(:error, "Please provide No K/P and password")
    |> redirect(to: ~p"/users/log-in")
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {_user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
