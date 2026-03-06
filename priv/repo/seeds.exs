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
alias Sppa.Repo

# Helper function to create and confirm a user
create_confirmed_user = fn no_kp, password, email, role_name, name ->
  case Accounts.get_user_by_no_kp(no_kp) do
    nil ->
      case Accounts.create_user(%{
             no_kp: no_kp,
             name: name,
             password: password,
             role: role_name
           }) do
        {:ok, user} ->
          # Update user with email, name, and confirm
          # Use change/2 to set email, name, and confirmed_at
          now = DateTime.utc_now(:second)

          updated_user =
            user
            |> Ecto.Changeset.change(email: email, name: name, confirmed_at: now)
            |> Repo.update!()

          IO.puts("✅ #{role_name} created successfully!")
          IO.puts("   No K/P: #{updated_user.no_kp}")
          IO.puts("   Name: #{updated_user.name}")
          IO.puts("   Email: #{updated_user.email}")
          IO.puts("   Role: #{updated_user.role}")
          IO.puts("   ID: #{updated_user.id}")

        {:error, changeset} ->
          errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
          IO.puts("❌ Failed to create #{role_name}:")
          IO.inspect(errors)
      end

    existing_user ->
      # Update existing user with name/role/email/confirmation if needed
      needs_name_update = is_nil(existing_user.name) || existing_user.name != name
      needs_email_update = existing_user.email != email
      needs_role_update = existing_user.role != role_name
      needs_confirm = is_nil(existing_user.confirmed_at)

      if needs_name_update || needs_email_update || needs_role_update || needs_confirm do
        updates = %{}
        updates = if needs_name_update, do: Map.put(updates, :name, name), else: updates
        updates = if needs_email_update, do: Map.put(updates, :email, email), else: updates
        updates = if needs_role_update, do: Map.put(updates, :role, role_name), else: updates

        changeset = Ecto.Changeset.change(existing_user, updates)

        # Add confirmed_at if needed
        changeset =
          if needs_confirm do
            now = DateTime.utc_now(:second)
            Ecto.Changeset.put_change(changeset, :confirmed_at, now)
          else
            changeset
          end

        updated_user = Repo.update!(changeset)

        IO.puts("✅ #{role_name} with No K/P '#{no_kp}' updated successfully!")
        IO.puts("   No K/P: #{updated_user.no_kp}")
        IO.puts("   Name: #{updated_user.name}")
        IO.puts("   Email: #{updated_user.email}")
        IO.puts("   Role: #{updated_user.role}")
      else
        IO.puts(
          "ℹ️  #{role_name} with No K/P '#{no_kp}' already exists with correct data. Skipping..."
        )
      end
  end
end

IO.puts("\n=== Creating seed users ===\n")

# Create Pembangun Sistem (System Developer)
IO.puts("Creating Pembangun Sistem...")

create_confirmed_user.(
  "800101010101",
  "pembangun123456",
  "pembangun.sistem@sppa.gov.my",
  "pembangun sistem",
  "Kairi Minach"
)

create_confirmed_user.(
  "123456127890",
  "PembangunSistem123",
  "pembangunsistem123@sppa.gov.my",
  "pembangun sistem",
  "Yozora"
)

create_confirmed_user.(
  "098765123456",
  "Mark_00123456",
  "mark_00@sppa.gov.my",
  "pembangun sistem",
  "Noct Flare"
)

# Create Pengurus Projek (Project Manager)
IO.puts("\nCreating Pengurus Projek...")

create_confirmed_user.(
  "800202020202",
  "projek12345678",
  "projek.manajer@sppa.gov.my",
  "pengurus projek",
  "Athur Pendragon"
)

create_confirmed_user.(
  "800202020203",
  "projek12345678",
  "pengurus.projek2@sppa.gov.my",
  "pengurus projek",
  "Kyle Lorren"
)

create_confirmed_user.(
  "800202020204",
  "projek12345678",
  "pengurus.projek3@sppa.gov.my",
  "pengurus projek",
  "Luke Skywalker"
)

# Create Ketua Penolong Pengarah (Deputy Director Head)
IO.puts("\nCreating Ketua Penolong Pengarah...")

create_confirmed_user.(
  "800303030303",
  "ketua123456789",
  "ketua.penolong.pengarah@sppa.gov.my",
  "ketua penolong pengarah",
  "Yshtolla Harvey"
)

IO.puts("\nCreating Ketua Unit...")

create_confirmed_user.(
  "00123567890",
  "KetuaUnit123456",
  "unit1@sistem.test",
  "ketua unit",
  "Richard Valentine"
)

create_confirmed_user.(
  "00123567891",
  "KetuaUnit123456",
  "unit2@sistem.test",
  "ketua unit",
  "Dinn Djarin"
)

create_confirmed_user.(
  "00123567892",
  "KetuaUnit123456",
  "unit3@sistem.test",
  "ketua unit",
  "Ahsoka Khano"
)

IO.puts("\n=== Seed users creation completed ===\n")

# Projek hanya dicipta dari halaman admin (Senarai Projek Diluluskan).
# Tiada projek dummy/sample dalam seed.
