# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Sppa.Repo.insert!(%Sppa.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Sppa.Accounts

# Create default seed user
IO.puts("Creating seed user...")

case Accounts.create_user(%{
  no_kp: "123456789012",
  password: "password123"
}) do
  {:ok, user} ->
    IO.puts("✅ User created successfully!")
    IO.puts("   No K/P: #{user.no_kp}")
    IO.puts("   ID: #{user.id}")

  {:error, changeset} ->
    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

    # Check if user already exists
    if Accounts.get_user_by_no_kp("123456789012") do
      IO.puts("ℹ️  User with No K/P '123456789012' already exists. Skipping...")
    else
      IO.puts("❌ Failed to create user:")
      IO.inspect(errors)
    end
end
