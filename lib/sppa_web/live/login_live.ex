defmodule SppaWeb.LoginLive do
  use SppaWeb, :live_view

  def mount(_params, _session, socket) do
    form = to_form(%{"no_kp" => "", "password" => ""}, as: :user)
    {:ok, assign(socket, form: form, page_title: "Log Masuk")}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    form = to_form(user_params, as: :user)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("login", %{"user" => _user_params}, socket) do
    # TODO: Implement actual authentication logic
    # After successful login, redirect to dashboard/home
    {:noreply, push_navigate(socket, to: ~p"/dashboard")}
  end
end
