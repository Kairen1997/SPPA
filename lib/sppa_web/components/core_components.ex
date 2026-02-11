defmodule SppaWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: SppaWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: SppaWeb.Endpoint,
    router: SppaWeb.Router,
    statics: SppaWeb.static_paths()

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50 flash-auto-hide"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>

          <p>{msg}</p>
        </div>
         <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :string
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}

    assigns =
      assign_new(assigns, :class, fn ->
        ["btn", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>{render_slot(@inner_block)}</.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>{render_slot(@inner_block)}</button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <span class="block text-sm font-medium text-gray-800">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="block text-sm font-medium text-gray-800 mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
           {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="block text-sm font-medium text-gray-800 mb-1">{@label}</span> <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="block text-sm font-medium text-gray-800 mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input",
            @errors != [] && (@error_class || "input-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-5" /> {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">{render_slot(@inner_block)}</h1>

        <p :if={@subtitle != []} class="text-sm text-base-content/70">{render_slot(@subtitle)}</p>
      </div>

      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>

          <th :if={@action != []}><span class="sr-only">{gettext("Actions")}</span></th>
        </tr>
      </thead>

      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>

          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>

          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(SppaWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(SppaWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Renders the system name used across the application.
  """
  attr :title, :string,
    default: "Sistem Pengurusan Pembangunan Aplikasi",
    doc: "Override the default system name if needed"

  def system_name(assigns) do
    ~H"""
    {@title}
    """
  end

  @doc """
  Renders the centered system title for headers (expects the parent header to be `relative`).
  """
  attr :title, :string,
    default: "SISTEM PENGURUSAN PEMBANGUNAN APLIKASI",
    doc: "Override the default system title if needed"

  attr :max_width_class, :string,
    default: "max-w-[70vw] sm:max-w-[55vw]",
    doc: "Controls truncation width across breakpoints"

  attr :class, :string,
    default:
      "text-sm font-semibold tracking-wide text-white/95 drop-shadow sm:text-base md:text-lg lg:text-xl",
    doc: "Additional/override classes for the title text"

  def system_title(assigns) do
    ~H"""
    <div class="pointer-events-none absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 px-3 text-center z-10 hidden sm:block">
      <span class={["block truncate", @max_width_class, @class]}>
        <.system_name title={@title} />
      </span>
    </div>
    """
  end

  @doc """
  Renders the standard header logos (Jata Sabah + JPKN).

  Used in the dashboard-style headers across many pages.
  """
  attr :height_class, :string,
    default: "h-10 sm:h-12 md:h-14",
    doc: "Responsive height classes for both logos"

  attr :gap_class, :string,
    default: "gap-3 sm:gap-4",
    doc: "Gap between logos"

  def header_logos(assigns) do
    ~H"""
    <div class={["flex items-center", @gap_class]}>
      <img
        src={~p"/images/Jata-Sabah.png"}
        alt="Jata Wilayah Sabah"
        class={[@height_class, "w-auto object-contain hidden sm:block"]}
      />
      <img
        src={~p"/images/logojpkn.png"}
        alt="Logo JPKN"
        class={[@height_class, "w-auto object-contain max-w-[60px] sm:max-w-none"]}
      />
    </div>
    """
  end

  @doc """
  Renders the main application sidebar used on the dashboard.

  Accepts whether the sidebar is open plus the paths needed for links and logo.
  Optionally takes the `current_scope` to allow role-based menu options.
  """
  attr :sidebar_open, :boolean, default: false
  attr :dashboard_path, :string, required: true
  attr :logo_src, :string, required: true
  attr :current_scope, :any, default: nil

  attr :current_path, :string,
    default: "/dashboard-pp",
    doc: "Current path for active link highlighting"

  def dashboard_sidebar(assigns) do
    ~H"""
    <aside
      class={[
        "fixed inset-y-0 left-0 w-72 bg-gradient-to-b from-gray-900/80 to-gray-800/80 backdrop-blur-xl text-white z-[60] transform transition-transform duration-300 ease-in-out shadow-2xl border-r border-white/10",
        if(@sidebar_open, do: "translate-x-0", else: "-translate-x-full pointer-events-none")
      ]}
      id="sidebar"
    >
      <div class="h-full flex flex-col">
        <div class="p-6 flex items-center justify-between border-b border-gray-700">
          <div class="flex-1 flex items-center justify-center">
            <img
              src={@logo_src}
              alt="Logo JPKN"
              class="h-24 w-auto object-contain"
            />
          </div>

          <button
            phx-click="toggle_sidebar"
            class="text-gray-400 hover:text-white hover:bg-gray-700 p-2 rounded-lg transition-all duration-200"
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>

        <nav class="flex-1 overflow-y-auto py-4 px-3">
          <%= if @current_scope && @current_scope.user && @current_scope.user.role == "pengurus projek" do %>
            <div class="space-y-1">
              <.link
                navigate={@dashboard_path}
                phx-click="close_sidebar"
                class={[
                  "flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200",
                  if(@current_path == "/dashboard-pp",
                    do: "bg-gradient-to-r from-blue-600 to-blue-500 text-white shadow-md",
                    else: "text-gray-200 hover:text-white hover:bg-gray-700/70"
                  )
                ]}
              >
                <.icon name="hero-squares-2x2" class="w-5 h-5" />
                <span class="font-medium">Dashboard</span>
              </.link>
              <.link
                navigate={~p"/senarai-projek-diluluskan"}
                phx-click="close_sidebar"
                class={[
                  "flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200",
                  if(@current_path == "/senarai-projek-diluluskan",
                    do: "bg-gradient-to-r from-blue-600 to-blue-500 text-white shadow-md",
                    else: "text-gray-200 hover:text-white hover:bg-gray-700/70"
                  )
                ]}
              >
                <.icon name="hero-folder" class="w-5 h-5" />
                <span class="font-medium">Senarai Projek</span>
              </.link>
            </div>
          <% else %>
            <.link
              navigate={@dashboard_path}
              phx-click="close_sidebar"
              class={[
                "flex items-center gap-3 px-4 py-3 rounded-lg mb-1 transition-all duration-200",
                "bg-gradient-to-r from-blue-600 to-blue-500 text-white shadow-md"
              ]}
            >
              <.icon name="hero-squares-2x2" class="w-5 h-5" />
              <span class="font-medium">Dashboard</span>
            </.link>
            <.link
              navigate={~p"/projek"}
              phx-click="close_sidebar"
              class="flex items-center gap-3 px-4 py-3 rounded-lg mb-1 text-gray-300 hover:bg-gray-700 hover:text-white transition-all duration-200"
            >
              <.icon name="hero-folder" class="w-5 h-5" /> <span>Senarai Projek</span>
            </.link>
          <% end %>
        </nav>
      </div>
    </aside>
    """
  end

  attr :id, :string, required: true, doc: "unique id for the table"
  attr :title, :string, required: true, doc: "category title"
  attr :questions, :list, required: true, doc: "list of question maps"
  attr :form, :any, required: true, doc: "the form struct"
  attr :tab_type, :string, required: true, doc: "either 'fr' or 'nfr'"
  attr :category_key, :string, required: true, doc: "category key for form params"

  # Reads fr/nfr form data from form source (map with "fr"/"nfr") for display.
  # Phoenix.HTML.Form.input_value does not reliably support deeply nested paths,
  # so we use get_in on the form params map to show saved soalan/maklumbalas/catatan.
  defp requirement_form_params(form) do
    if is_map(form.source) and not is_struct(form.source) do
      form.source
    else
      form.params || %{}
    end
  end

  defp requirement_form_value(form, tab_type, category_key, question_no, field, default) do
    params = requirement_form_params(form)
    path = [tab_type, category_key, to_string(question_no), field]

    case get_in(params, path) do
      nil -> default
      val -> val
    end
  end

  defp requirement_form_value_raw(form, tab_type, category_key, question_no, field) do
    params = requirement_form_params(form)
    get_in(params, [tab_type, category_key, to_string(question_no), field])
  end

  defp requirement_has_data?(form, tab_type, category_key, question) do
    # Check soalan from form or question.soalan
    soalan =
      requirement_form_value(
        form,
        tab_type,
        category_key,
        question.no,
        "soalan",
        question.soalan || ""
      )
      |> String.trim()

    # Check maklumbalas from form
    maklumbalas_raw =
      requirement_form_value_raw(form, tab_type, category_key, question.no, "maklumbalas")

    maklumbalas =
      cond do
        is_list(maklumbalas_raw) -> length(maklumbalas_raw) > 0
        is_binary(maklumbalas_raw) -> String.trim(maklumbalas_raw) != ""
        true -> false
      end

    # Check catatan from form
    catatan =
      requirement_form_value(form, tab_type, category_key, question.no, "catatan", "")
      |> String.trim()

    # Return true if at least one field has data
    soalan != "" || maklumbalas || catatan != ""
  end

  @doc """
  Renders a requirement table for the soal selidik form.

  ## Examples

      <.requirement_table
        id="pendaftaran-login"
        title="Pendaftaran & Login"
        questions={@questions}
        form={@form}
        tab_type="fr"
        category_key="pendaftaran_login"
      />
  """
  def requirement_table(assigns) do
    ~H"""
    <div class="border border-gray-300 rounded-lg overflow-hidden mb-4">
      <%!-- Tambah Baris Button - Top Right --%>
      <div class="p-2 bg-gray-50 border-b border-gray-300 flex justify-end">
        <button
          type="button"
          phx-click="add_question"
          phx-value-tab_type={@tab_type}
          phx-value-category_key={@category_key}
          class="px-3 py-1.5 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 shadow transition-all duration-200 text-sm flex items-center gap-2"
          title="Tambah baris soalan baru"
        >
          <.icon name="hero-plus" class="w-4 h-4" /> <span>Tambah Baris</span>
        </button>
      </div>

      <table class="w-full border-collapse text-sm">
        <thead>
          <tr class="bg-gray-100 border-b border-gray-400">
            <th
              class="px-3 py-2 text-left font-semibold text-gray-700 border-r border-gray-400"
              style="width: 6%;"
            >
              No
            </th>

            <th
              class="px-3 py-2 text-left font-semibold text-gray-700 border-r border-gray-400"
              style="width: 40%;"
            >
              Soalan
            </th>

            <th
              class="px-3 py-2 text-left font-semibold text-gray-700 border-r border-gray-400"
              style="width: 25%;"
            >
              Maklumbalas
            </th>

            <th
              class="px-3 py-2 text-left font-semibold text-gray-700 border-r border-gray-400"
              style="width: 25%;"
            >
              Catatan
            </th>

            <th class="px-3 py-2 text-left font-semibold text-gray-700" style="width: 10%;">
              Tindakan
            </th>
          </tr>
        </thead>

        <tbody class="divide-y divide-gray-300">
          <tr :for={question <- @questions} class="hover:bg-gray-50">
            <td class="px-3 py-2 border-r border-gray-400 align-top">
              <div class="px-2 py-1 text-sm font-medium text-gray-900">{question.no}</div>
            </td>

            <td class="px-3 py-2 border-r border-gray-400 align-top">
              <textarea
                id={"soalan-#{@tab_type}-#{@category_key}-#{question.no}"}
                name={"soal_selidik[#{@tab_type}][#{@category_key}][#{question.no}][soalan]"}
                rows="1"
                class="w-full px-2 py-1.5 text-sm text-gray-900 border border-gray-400 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500 resize-none overflow-hidden"
                placeholder="Masukkan soalan..."
                phx-change="validate"
                phx-value-tab_type={@tab_type}
                phx-value-category_key={@category_key}
                phx-value-question_no={question.no}
                phx-value-field="soalan"
                phx-hook="AutoResizeTextarea"
                style="min-height: 2.5rem; max-height: 20rem;"
              >{requirement_form_value(@form, @tab_type, @category_key, question.no, "soalan", question.soalan || "")}</textarea>
            </td>

            <td class="px-3 py-2 border-r border-gray-400 align-top">
              <%= cond do %>
                <% question.type == :text -> %>
                  <textarea
                    id={"maklumbalas-#{@tab_type}-#{@category_key}-#{question.no}"}
                    name={"soal_selidik[#{@tab_type}][#{@category_key}][#{question.no}][maklumbalas]"}
                    rows="1"
                    class="w-full px-2 py-1.5 text-sm text-gray-900 border border-gray-400 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500 resize-none overflow-hidden"
                    placeholder="Masukkan maklumbalas..."
                    phx-change="validate"
                    phx-value-tab_type={@tab_type}
                    phx-value-category_key={@category_key}
                    phx-value-question_no={question.no}
                    phx-value-field="maklumbalas"
                    phx-hook="AutoResizeTextarea"
                    style="min-height: 2.5rem; max-height: 20rem;"
                  >{requirement_form_value(@form, @tab_type, @category_key, question.no, "maklumbalas", "")}</textarea>
                <% question.type == :textarea -> %>
                  <textarea
                    id={"maklumbalas-#{@tab_type}-#{@category_key}-#{question.no}"}
                    name={"soal_selidik[#{@tab_type}][#{@category_key}][#{question.no}][maklumbalas]"}
                    rows="1"
                    class="w-full px-2 py-1.5 text-sm text-gray-900 border border-gray-400 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500 resize-none overflow-hidden"
                    placeholder="Masukkan maklumbalas..."
                    phx-change="validate"
                    phx-value-tab_type={@tab_type}
                    phx-value-category_key={@category_key}
                    phx-value-question_no={question.no}
                    phx-value-field="maklumbalas"
                    phx-hook="AutoResizeTextarea"
                    style="min-height: 2.5rem; max-height: 20rem;"
                  >{requirement_form_value(@form, @tab_type, @category_key, question.no, "maklumbalas", "")}</textarea>
                <% question.type == :select -> %>
                  <select
                    id={"maklumbalas-#{@tab_type}-#{@category_key}-#{question.no}"}
                    name={"soal_selidik[#{@tab_type}][#{@category_key}][#{question.no}][maklumbalas]"}
                    class="w-full px-2 py-1.5 text-sm border border-gray-400 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                    phx-change="validate"
                    phx-value-tab_type={@tab_type}
                    phx-value-category_key={@category_key}
                    phx-value-question_no={question.no}
                    phx-value-field="maklumbalas"
                    phx-hook="SaveFieldOnBlur"
                  >
                    <option value="">-- Pilih --</option>

                    <option
                      :for={option <- question.options || []}
                      value={option}
                      selected={
                        requirement_form_value(
                          @form,
                          @tab_type,
                          @category_key,
                          question.no,
                          "maklumbalas",
                          ""
                        ) == option
                      }
                    >
                      {option}
                    </option>
                  </select>
                <% question.type == :checkbox -> %>
                  <div class="flex flex-col gap-2">
                    <%= for option <- question.options || [] do %>
                      <label class="flex items-center gap-2 cursor-pointer">
                        <input
                          id={"maklumbalas-#{@tab_type}-#{@category_key}-#{question.no}-#{option}"}
                          type="checkbox"
                          name={"soal_selidik[#{@tab_type}][#{@category_key}][#{question.no}][maklumbalas][]"}
                          value={option}
                          checked={
                            case requirement_form_value_raw(
                                   @form,
                                   @tab_type,
                                   @category_key,
                                   question.no,
                                   "maklumbalas"
                                 ) do
                              values when is_list(values) -> option in values
                              value when is_binary(value) -> value == option
                              _ -> false
                            end
                          }
                          phx-change="validate"
                          phx-value-tab_type={@tab_type}
                          phx-value-category_key={@category_key}
                          phx-value-question_no={question.no}
                          phx-value-field="maklumbalas"
                          phx-hook="SaveFieldOnBlur"
                          class="rounded border-gray-400 text-blue-600 focus:ring-blue-500 cursor-pointer"
                        /> <span class="text-sm text-gray-700">{option}</span>
                      </label>
                    <% end %>
                  </div>
                <% true -> %>
                  <textarea
                    id={"maklumbalas-#{@tab_type}-#{@category_key}-#{question.no}"}
                    name={"soal_selidik[#{@tab_type}][#{@category_key}][#{question.no}][maklumbalas]"}
                    rows="1"
                    class="w-full px-2 py-1.5 text-sm text-gray-900 border border-gray-400 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500 resize-none overflow-hidden"
                    placeholder="Masukkan maklumbalas..."
                    phx-change="validate"
                    phx-value-tab_type={@tab_type}
                    phx-value-category_key={@category_key}
                    phx-value-question_no={question.no}
                    phx-value-field="maklumbalas"
                    phx-hook="AutoResizeTextarea"
                    style="min-height: 2.5rem; max-height: 20rem;"
                  >{requirement_form_value(@form, @tab_type, @category_key, question.no, "maklumbalas", "")}</textarea>
              <% end %>
            </td>

            <td class="px-3 py-2 border-r border-gray-400 align-top">
              <textarea
                id={"catatan-#{@tab_type}-#{@category_key}-#{question.no}"}
                name={"soal_selidik[#{@tab_type}][#{@category_key}][#{question.no}][catatan]"}
                rows="1"
                class="w-full px-2 py-1.5 text-sm text-gray-900 border border-gray-400 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500 resize-none overflow-hidden"
                placeholder="Catatan..."
                phx-change="validate"
                phx-value-tab_type={@tab_type}
                phx-value-category_key={@category_key}
                phx-value-question_no={question.no}
                phx-value-field="catatan"
                phx-hook="AutoResizeTextarea"
                style="min-height: 2.5rem; max-height: 20rem;"
              >{requirement_form_value(@form, @tab_type, @category_key, question.no, "catatan", "")}</textarea>
            </td>

            <td class="px-3 py-2 align-top">
              <div class="flex items-center gap-2">
                <%= if requirement_has_data?(@form, @tab_type, @category_key, question) do %>
                  <button
                    type="button"
                    phx-click="edit_question"
                    phx-value-tab_type={@tab_type}
                    phx-value-category_key={@category_key}
                    phx-value-question_no={question.no}
                    class="p-1.5 text-blue-600 hover:text-blue-800 hover:bg-blue-50 rounded transition-colors duration-200"
                    title="Edit"
                  >
                    <.icon name="hero-pencil" class="w-4 h-4" />
                  </button>
                <% end %>

                <button
                  type="button"
                  phx-click="delete_question"
                  phx-value-tab_type={@tab_type}
                  phx-value-category_key={@category_key}
                  phx-value-question_no={question.no}
                  class="p-1.5 text-red-600 hover:text-red-800 hover:bg-red-50 rounded transition-colors duration-200"
                  title="Padam"
                >
                  <.icon name="hero-trash" class="w-4 h-4" />
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
