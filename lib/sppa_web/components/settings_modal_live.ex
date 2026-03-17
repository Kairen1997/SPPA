defmodule SppaWeb.Components.SettingsModalLive do
  @moduledoc """
  Modal for account (password) settings. Renders overlay and form;
  parent LiveView should assign show_settings_modal and handle open/close.
  """
  use SppaWeb, :live_component

  alias Sppa.Accounts

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if socket.assigns[:password_form] == nil && socket.assigns.current_scope do
        user = socket.assigns.current_scope.user
        cs = Accounts.change_user_password(user, %{}, hash_password: false)

        socket
        |> assign(:password_form, to_form(cs))
        |> assign(:trigger_submit, false)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed inset-0 z-[100] flex items-center justify-center bg-blue-900/60 p-4"
    >
      <div
        class="max-w-xl w-full bg-white shadow-2xl rounded-2xl border border-blue-200 overflow-hidden"
        phx-click-away="close_settings"
        phx-target={@myself}
      >
        <div class="bg-gradient-to-r from-blue-600 to-blue-700 px-6 sm:px-8 py-5 text-center">
          <h2 class="text-xl font-semibold text-white">Account Settings</h2>

          <p class="mt-1 text-sm text-blue-100">Manage your account password settings</p>
        </div>

        <div class="p-6 sm:p-8 space-y-6">
          <.form
            :if={@password_form}
            for={@password_form}
            id="password_form"
            action={~p"/users/update-password"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
            phx-target={@myself}
          >
            <.input
              field={@password_form[:password]}
              type="password"
              label="Kata Laluan Baharu"
              autocomplete="new-password"
              required
            />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Sahkan Kata Laluan baharu"
              autocomplete="new-password"
            />
            <button
              type="submit"
              phx-disable-with="Saving..."
              class="mt-2 px-4 py-2 rounded-lg font-medium text-white bg-blue-600 hover:bg-blue-700 transition-colors"
            >
              Simpan Kata Laluan
            </button>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("close_settings", _params, socket) do
    send(self(), :close_settings_modal)
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user

    password_form =
      user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  @impl true
  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply,
         socket
         |> assign(:trigger_submit, true)
         |> assign(:password_form, to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
