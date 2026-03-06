defmodule Mix.Tasks.Sppa.DeleteDummyProjects do
  @shortdoc "Padam projek dummy (projek tanpa approved_project_id). Simpan data dari admin sahaja."
  @moduledoc """
  Memadam semua projek yang tidak mempunyai approved_project_id (projek yang tidak
  dicipta dari Senarai Projek Diluluskan / halaman admin).

  ## Penggunaan

      mix sppa.delete_dummy_projects

  Selepas dijalankan, hanya projek yang berasal dari halaman admin akan kekal dalam pangkalan data.
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case Sppa.Projects.delete_dummy_projects() do
      {:ok, 0} ->
        Mix.shell().info("Tiada projek dummy. Semua projek ada approved_project_id.")

      {:ok, n} ->
        Mix.shell().info("Berjaya padam #{n} projek dummy. Hanya data dari admin kekal.")

      {:error, reason} ->
        Mix.shell().error("Gagal memadam projek dummy: #{inspect(reason)}")
        System.halt(1)
    end
  end
end
