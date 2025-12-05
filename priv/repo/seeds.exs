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
alias Sppa.Projects.Project
alias Sppa.Repo
import Ecto.Query, only: [from: 2]

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

IO.puts("=== Creating sample projects for dashboard 'Aktiviti Terkini' ===\n")

# Fetch the seed users we just ensured exist
developer = Accounts.get_user_by_no_kp("800101010101")
project_manager = Accounts.get_user_by_no_kp("800202020202")
owner = Accounts.get_user_by_no_kp("800303030303")

if developer && project_manager && owner do
  now =
    DateTime.utc_now()
    |> DateTime.truncate(:second)

  owner_projects = [
    %{
      name: "Sistem Pemantauan Prestasi Aset Negeri",
      status: "Dalam Pembangunan",
      hours_offset: -1
    },
    %{
      name: "Portal Pelaporan Prestasi Jabatan",
      status: "UAT",
      hours_offset: -6
    },
    %{
      name: "Dashboard Analitik Belanjawan",
      status: "Selesai",
      hours_offset: -24
    },
    %{
      name: "Aplikasi Mudah Alih Pemantauan Projek",
      status: "Pengurusan Perubahan",
      hours_offset: -48
    },
    %{
      name: "Sistem Pengurusan Risiko Projek",
      status: "Ditangguhkan",
      hours_offset: -72
    }
  ]

  developer_projects = [
    %{
      name: "Refaktor Modul Pengurusan Pengguna",
      status: "Dalam Pembangunan",
      hours_offset: -2
    },
    %{
      name: "Integrasi Single Sign-On (SSO)",
      status: "UAT",
      hours_offset: -8
    },
    %{
      name: "Penstabilan Modul Laporan",
      status: "Selesai",
      hours_offset: -30
    }
  ]

  owner_existing_count =
    from(p in Project, where: p.user_id == ^owner.id)
    |> Repo.aggregate(:count, :id)
    |> Kernel.||(0)

  if owner_existing_count == 0 do
    Enum.each(owner_projects, fn attrs ->
      last_updated =
        DateTime.add(
          now,
          attrs.hours_offset * 60 * 60,
          :second
        )

      %Project{
        name: attrs.name,
        status: attrs.status,
        last_updated: last_updated,
        user_id: owner.id,
        developer_id: developer.id,
        project_manager_id: project_manager.id
      }
      |> Repo.insert!()
    end)

    IO.puts("✅ Sample projects created for owner for 'Aktiviti Terkini' schedule.\n")
  else
    IO.puts(
      "ℹ️  Owner already has #{owner_existing_count} project(s). Skipping owner project seeds.\n"
    )
  end

  developer_existing_count =
    from(p in Project, where: p.user_id == ^developer.id)
    |> Repo.aggregate(:count, :id)
    |> Kernel.||(0)

  if developer_existing_count == 0 do
    Enum.each(developer_projects, fn attrs ->
      last_updated =
        DateTime.add(
          now,
          attrs.hours_offset * 60 * 60,
          :second
        )

      %Project{
        name: attrs.name,
        status: attrs.status,
        last_updated: last_updated,
        user_id: developer.id,
        developer_id: developer.id,
        project_manager_id: project_manager.id
      }
      |> Repo.insert!()
    end)

    IO.puts("✅ Sample projects created for developer for 'Aktiviti Terkini' schedule.\n")
  else
    IO.puts(
      "ℹ️  Developer already has #{developer_existing_count} project(s). Skipping developer project seeds.\n"
    )
  end
else
  IO.puts(
    "⚠️  One or more seed users are missing. Skipping project seeds for 'Aktiviti Terkini'.\n"
  )
end
