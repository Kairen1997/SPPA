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
alias Sppa.Accounts.User
alias Sppa.Repo

# Helper function to create and confirm a user
create_confirmed_user = fn no_kp, password, email, role_name ->
  case Accounts.get_user_by_no_kp(no_kp) do
    nil ->
      case Accounts.create_user(%{
        no_kp: no_kp,
        password: password,
        role: role_name
      }) do
        {:ok, user} ->
          # Update user with email and confirm
          updated_user =
            user
            |> User.email_changeset(%{email: email}, validate_unique: false)
            |> User.confirm_changeset()
            |> Repo.update!()

          IO.puts("✅ #{role_name} created successfully!")
          IO.puts("   No K/P: #{updated_user.no_kp}")
          IO.puts("   Email: #{updated_user.email}")
          IO.puts("   Role: #{updated_user.role}")
          IO.puts("   ID: #{updated_user.id}")

        {:error, changeset} ->
          errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
          IO.puts("❌ Failed to create #{role_name}:")
          IO.inspect(errors)
      end

    _existing_user ->
      IO.puts("ℹ️  #{role_name} with No K/P '#{no_kp}' already exists. Skipping...")
  end
end

IO.puts("\n=== Creating seed users ===\n")

# Create Pembangun Sistem (System Developer)
IO.puts("Creating Pembangun Sistem...")
create_confirmed_user.(
  "800101010101",
  "pembangun123456",
  "pembangun.sistem@sppa.gov.my",
  "pembangun sistem"
)

# Create Pengurus Projek (Project Manager)
IO.puts("\nCreating Pengurus Projek...")
create_confirmed_user.(
  "800202020202",
  "projek12345678",
  "projek.manajer@sppa.gov.my",
  "pengurus projek"
)

# Create Ketua Penolong Pengarah (Deputy Director Head)
IO.puts("\nCreating Ketua Penolong Pengarah...")
create_confirmed_user.(
  "800303030303",
  "ketua123456789",
  "ketua.penolong.pengarah@sppa.gov.my",
  "ketua penolong pengarah"
)

IO.puts("\n=== Seed users creation completed ===\n")
