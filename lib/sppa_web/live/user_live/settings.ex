defmodule SppaWeb.UserLive.Settings do
  use SppaWeb, :live_view

  on_mount {SppaWeb.UserAuth, :require_sudo_mode}

  alias Sppa.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="fixed inset-0 z-40 flex items-center justify-center bg-base-300/60">
        <div class="max-w-xl w-full mx-4 bg-base-100 shadow-2xl rounded-2xl border border-base-200 p-6 sm:p-8 space-y-6">
          <div class="text-center">
            <.header>
              Account Settings
              <:subtitle>Manage your account password settings</:subtitle>
            </.header>
          </div>
          
          <div class="flex justify-start">
            <.link navigate={~p"/dashboard"}><.button>Kembali ke Dashboard</.button></.link>
          </div>
          
          <.form
            for={@password_form}
            id="password_form"
            action={~p"/users/update-password"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
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
            /> <.button variant="primary" phx-disable-with="Saving...">Simpan Kata Laluan</.button>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
