defmodule Guard.OrganizationCleaner do
  use Quantum, otp_app: :guard

  alias Guard.Store.Organization

  require Logger

  def process do
    Watchman.benchmark("guard.organization_cleaner", fn ->
      Logger.info("Starting organization cleaner")

      Organization.find_candidates_for_hard_destroy()
      |> Enum.each(fn org ->
        Logger.info("Hard destroying organization #{org.id}")

        case Organization.hard_destroy(org) do
          {:ok, _} ->
            Logger.info("Hard destroyed organization #{org.id}")

          {:error, error} ->
            Logger.error("Failed to hard destroy organization #{org.id}: #{error}")
        end
      end)

      Logger.info("Finished organization cleaner")
      :ok
    end)
  end
end
