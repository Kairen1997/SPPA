defmodule SppaWeb.UserLive.Login do
  use SppaWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} full_width={true}>
      <div
        class="min-h-screen flex items-center justify-center relative overflow-hidden bg-cover bg-center bg-no-repeat"
        style={"background-image: url(" <> ~p"/images/Menara Kinabalu.jpg" <> ")"}
      >
        <%!-- Login Form Container --%>
        <div
          class="relative z-10 mx-4"
          style="width: 600px; max-width: 90vw; min-width: 500px; flex-shrink: 0;"
        >
          <div
            class="bg-white/50 rounded-2xl shadow-2xl"
            style="box-sizing: border-box; padding: 40px; width: 100%;"
          >
            <%!-- Logo Section --%>
            <div class="flex justify-center mb-6">
              <img
                src={~p"/images/logojpkn.png"}
                alt="JPKN Logo"
                class="h-24 w-auto object-contain"
              />
            </div>

            <%!-- System Title --%>
            <div class="text-center mb-8">
              <h2 class="text-lg font-semibold text-black leading-relaxed">
                Sistem Pengurusan Pembangunan Aplikasi
              </h2>
            </div>

            <%!-- Login Form --%>
            <.form
              for={@form}
              id="login-form"
              action={~p"/users/log-in"}
              method="post"
              phx-change="validate"
              class="space-y-5"
            >
              <%!-- No K/P Field --%>
              <div class="flex items-center gap-4">
                <label
                  for="user_no_kp"
                  class="text-black font-medium w-28 text-sm"
                >
                  No K/P
                </label>
                <div class="flex-1">
                  <.input
                    field={@form[:no_kp]}
                    type="text"
                    placeholder="Masukkan No K/P"
                    class="w-full bg-white border border-gray-300 rounded-lg px-3 py-2.5 text-gray-900 placeholder:text-gray-400 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:outline-none"
                  />
                </div>
              </div>

              <%!-- Password Field --%>
              <div class="flex items-center gap-4">
                <label
                  for="user_password"
                  class="text-black font-medium w-28 text-sm"
                >
                  Kata Laluan
                </label>
                <div class="flex-1">
                  <.input
                    field={@form[:password]}
                    type="password"
                    placeholder="Masukkan Kata Laluan"
                    class="w-full bg-white border border-gray-300 rounded-lg px-3 py-2.5 text-gray-900 placeholder:text-gray-400 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:outline-none"
                  />
                </div>
              </div>

              <%!-- Login Button --%>
              <div class="pt-4 flex justify-center">
                <button
                  type="submit"
                  class="bg-blue-600 hover:bg-blue-700 active:bg-blue-800 text-white font-semibold py-2.5 px-8 rounded-lg transition-all duration-200 shadow-md hover:shadow-lg"
                >
                  Log Masuk
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    form = to_form(%{"no_kp" => "", "password" => ""}, as: :user)
    {:ok, assign(socket, form: form, page_title: "Log Masuk")}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form = to_form(user_params, as: :user)
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("login", %{"user" => _user_params}, socket) do
    # Redirect to controller action for proper session handling
    socket =
      socket
      |> redirect(to: ~p"/users/log-in", external: true)

    {:noreply, socket}
  end
end
