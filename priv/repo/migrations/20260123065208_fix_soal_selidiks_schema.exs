defmodule Sppa.Repo.Migrations.FixSoalSelidiksSchema do
  use Ecto.Migration

  def up do
    # Drop old foreign key constraints to modify them
    execute "ALTER TABLE soal_selidiks DROP CONSTRAINT IF EXISTS soal_selidiks_project_id_fkey"
    execute "ALTER TABLE soal_selidiks DROP CONSTRAINT IF EXISTS soal_selidiks_user_id_fkey"

    # Remove old disediakan_oleh columns
    alter table(:soal_selidiks) do
      remove :disediakan_oleh_nama
      remove :disediakan_oleh_jawatan
      remove :disediakan_oleh_tarikh
    end

    # Add missing map columns
    alter table(:soal_selidiks) do
      add :fr_categories, :map, default: %{}
      add :nfr_categories, :map, default: %{}
      add :fr_data, :map, default: %{}
      add :nfr_data, :map, default: %{}
      add :disediakan_oleh, :map, default: %{}
      add :custom_tabs, :map, default: %{}
      add :tabs, :map, default: %{}
    end

    # Recreate foreign keys with correct delete rules
    execute """
      ALTER TABLE soal_selidiks
      ADD CONSTRAINT soal_selidiks_project_id_fkey
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL
    """

    execute """
      ALTER TABLE soal_selidiks
      ADD CONSTRAINT soal_selidiks_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    """
  end

  def down do
    # Drop new foreign key constraints
    execute "ALTER TABLE soal_selidiks DROP CONSTRAINT IF EXISTS soal_selidiks_project_id_fkey"
    execute "ALTER TABLE soal_selidiks DROP CONSTRAINT IF EXISTS soal_selidiks_user_id_fkey"

    # Remove new map columns
    alter table(:soal_selidiks) do
      remove :fr_categories
      remove :nfr_categories
      remove :fr_data
      remove :nfr_data
      remove :disediakan_oleh
      remove :custom_tabs
      remove :tabs
    end

    # Restore old disediakan_oleh columns
    alter table(:soal_selidiks) do
      add :disediakan_oleh_nama, :string
      add :disediakan_oleh_jawatan, :string
      add :disediakan_oleh_tarikh, :date
    end

    # Restore old foreign keys with CASCADE
    execute """
      ALTER TABLE soal_selidiks
      ADD CONSTRAINT soal_selidiks_project_id_fkey
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
    """

    execute """
      ALTER TABLE soal_selidiks
      ADD CONSTRAINT soal_selidiks_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    """
  end
end
