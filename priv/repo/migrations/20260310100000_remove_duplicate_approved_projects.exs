defmodule Sppa.Repo.Migrations.RemoveDuplicateApprovedProjects do
  use Ecto.Migration

  def up do
    # 1) Normalise duplicate approved_projects (same external_application_id)
    #    - Repoint projects.approved_project_id to the kept row (min id)
    #    - Delete extra approved_projects rows

    execute("""
    UPDATE projects p
    SET approved_project_id = sub.keep_id
    FROM (
      SELECT ap.id AS duplicate_id,
             MIN(ap2.id) AS keep_id
      FROM approved_projects ap
      JOIN approved_projects ap2
        ON ap.external_application_id = ap2.external_application_id
      GROUP BY ap.id
    ) AS sub
    WHERE p.approved_project_id = sub.duplicate_id
      AND sub.keep_id <> sub.duplicate_id
    """)

    execute("""
    DELETE FROM approved_projects
    WHERE id NOT IN (
      SELECT MIN(id) FROM approved_projects GROUP BY external_application_id
    )
    """)

    # 2) Normalise duplicate projects (same approved_project_id)
    #    Keep the oldest project (smallest id) per approved_project_id.

    execute("""
    DELETE FROM projects p
    USING projects dup
    WHERE p.id <> dup.id
      AND p.approved_project_id IS NOT NULL
      AND p.approved_project_id = dup.approved_project_id
      AND p.id > dup.id
    """)

    # 3) Optional safety: enforce uniqueness on approved_project_id at DB level
    create unique_index(:projects, [:approved_project_id],
      where: "approved_project_id IS NOT NULL",
      name: :projects_approved_project_id_unique
    )
  end

  def down do
    drop_if_exists(index(:projects, [:approved_project_id], name: :projects_approved_project_id_unique))

    # Data deletions in up/0 are irreversible in a meaningful way, so we leave them as-is.
    :ok
  end
end

