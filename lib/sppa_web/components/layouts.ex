defmodule SppaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use SppaWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  attr :full_width, :boolean, default: false

  attr :notifications_open, :boolean, default: false
  attr :notifications_count, :integer, default: 0
  attr :activities, :list, default: []
  attr :profile_menu_open, :boolean, default: false

  def app(assigns) do
    ~H"""
    <%= if @current_scope && @current_scope.user && !@full_width do %>
      <%!-- Global Header Bar for non-full-width pages --%>
      <header class="fixed top-0 left-0 right-0 bg-gradient-to-r from-blue-600 to-blue-700 border-b border-blue-700 px-4 sm:px-6 py-3 flex items-center justify-end shadow-md z-50 relative">
        <.system_title />
        <.header_actions
          notifications_open={@notifications_open}
          notifications_count={@notifications_count}
          activities={@activities}
          profile_menu_open={@profile_menu_open}
          current_scope={@current_scope}
        />
      </header>
    <% end %>

    <%= if @full_width do %>
      {render_slot(@inner_block)}
    <% else %>
      <main class={[
        "px-4 sm:px-6 lg:px-8",
        if(@current_scope && @current_scope.user, do: "pt-20", else: "py-20")
      ]}>
        <div class="mx-auto max-w-2xl space-y-4">{render_slot(@inner_block)}</div>
      </main>
    <% end %>
    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} /> <.flash kind={:error} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex flex-row items-center border-2 border-gray-300 dark:border-gray-600 bg-gray-200 dark:bg-gray-700 rounded-full p-1">
      <div class="absolute w-1/2 h-[calc(100%-0.5rem)] rounded-full bg-white dark:bg-gray-800 transition-all duration-200 left-1 [[data-theme=light]_&]:left-1 [[data-theme=dark]_&]:left-[calc(50%+0.125rem)]" />
      <button
        class="relative flex p-1.5 cursor-pointer w-1/2 justify-center z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        aria-label="Light theme"
      >
        <.icon name="hero-sun" class="size-4 text-gray-700 dark:text-gray-300" />
      </button>
      <button
        class="relative flex p-1.5 cursor-pointer w-1/2 justify-center z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        aria-label="Dark theme"
      >
        <.icon name="hero-moon" class="size-4 text-gray-700 dark:text-gray-300" />
      </button>
    </div>
    """
  end
end
