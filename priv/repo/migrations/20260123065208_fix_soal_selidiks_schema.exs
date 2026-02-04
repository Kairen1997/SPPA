defmodule Sppa.Repo.Migrations.FixSoalSelidiksSchema do
  use Ecto.Migration

  def up do
    # Drop old foreign key constraints to modify them
    execute "ALTER TABLE soal_selidiks DROP CONSTRAINT IF EXISTS soal_selidiks_project_id_fkey"
    execute "ALTER TABLE soal_selidiks DROP CONSTRAINT IF EXISTS soal_selidiks_user_id_fkey"

    # Remove old disediakan_oleh columns if they exist
    execute "ALTER TABLE soal_selidiks DROP COLUMN IF EXISTS disediakan_oleh_nama"
    execute "ALTER TABLE soal_selidiks DROP COLUMN IF EXISTS disediakan_oleh_jawatan"
    execute "ALTER TABLE soal_selidiks DROP COLUMN IF EXISTS disediakan_oleh_tarikh"

    # Add missing map columns (only if they don't exist)
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'soal_selidiks' AND column_name = 'fr_categories') THEN
        ALTER TABLE soal_selidiks ADD COLUMN fr_categories jsonb DEFAULT '{}'::jsonb;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'soal_selidiks' AND column_name = 'nfr_categories') THEN
        ALTER TABLE soal_selidiks ADD COLUMN nfr_categories jsonb DEFAULT '{}'::jsonb;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'soal_selidiks' AND column_name = 'fr_data') THEN
        ALTER TABLE soal_selidiks ADD COLUMN fr_data jsonb DEFAULT '{}'::jsonb;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'soal_selidiks' AND column_name = 'nfr_data') THEN
        ALTER TABLE soal_selidiks ADD COLUMN nfr_data jsonb DEFAULT '{}'::jsonb;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'soal_selidiks' AND column_name = 'disediakan_oleh') THEN
        ALTER TABLE soal_selidiks ADD COLUMN disediakan_oleh jsonb DEFAULT '{}'::jsonb;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'soal_selidiks' AND column_name = 'custom_tabs') THEN
        ALTER TABLE soal_selidiks ADD COLUMN custom_tabs jsonb DEFAULT '{}'::jsonb;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'soal_selidiks' AND column_name = 'tabs') THEN
        ALTER TABLE soal_selidiks ADD COLUMN tabs jsonb DEFAULT '{}'::jsonb;
      END IF;
    END $$;
    """

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
