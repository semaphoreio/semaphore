defmodule Guard.OrganizationCleaner do
  use Quantum, otp_app: :guard

  alias Guard.Store.Organization

  require Logger

  @chunk_size 10

  def process do
    Organization.find_candidates_for_hard_destroy()
    |> Stream.chunk_every(@chunk_size)
    |> Stream.each(fn orgs ->
      orgs
      |> Task.async_stream(
        fn org ->
          Logger.info("Hard destroying organization #{org.id}")
          Organization.hard_destroy(org)
        end,
        max_concurrency: @chunk_size,
        timeout: 30_000
      )
      |> Stream.run()
    end)
    |> Stream.run()

    :ok
  end
end
