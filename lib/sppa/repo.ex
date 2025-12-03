defmodule Sppa.Repo do
  use Ecto.Repo,
    otp_app: :sppa,
    adapter: Ecto.Adapters.Postgres
end
