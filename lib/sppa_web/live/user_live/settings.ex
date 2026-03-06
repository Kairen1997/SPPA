defmodule SppaWeb.UserLive.Settings do
  @moduledoc """
  Legacy routes for /users/settings. The :edit action redirects to dashboard
  (settings are now in a modal). The :confirm_email action applies the email
  change token and redirects to dashboard.
  """
  use SppaWeb, :live_view

  on_mount {SppaWeb.UserAuth, :require_authenticated}

  alias Sppa.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) when is_binary(token) do
    # confirm_email action
    user = socket.assigns.current_scope.user

    case Accounts.update_user_email(user, token) do
      {:ok, _user} ->
        {:ok,
         socket
         |> put_flash(:info, "Email changed successfully.")
         |> redirect(to: ~p"/dashboard")}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Email change link is invalid or it has expired.")
         |> redirect(to: ~p"/dashboard")}
    end
  end

  def mount(_params, _session, socket) do
    # :edit action - no longer show settings page; redirect to dashboard
    {:ok, redirect(socket, to: ~p"/dashboard")}
  end

  @impl true
  def render(assigns) do
    # Not reached: both mount paths redirect
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="p-4">Redirecting...</div>
    </Layouts.app>
    """
  end
end
