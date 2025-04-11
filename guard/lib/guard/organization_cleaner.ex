defmodule Guard.OrganizationCleaner do
  use Quantum, otp_app: :guard

  alias Guard.Store.Organization

  require Logger

  @chunk_size 10

  def process do
    Organization.find_candidates_for_hard_destroy()
    |> Stream.chunk_every(@chunk_size)
    |> Stream.map(fn projects ->
      Enum.map(projects, fn project ->
        Logger.info("Hard destroying organization #{project.id}")
        Organization.hard_destroy(project)
      end)
    end)
    |> Stream.run()

    :ok
  end
end
