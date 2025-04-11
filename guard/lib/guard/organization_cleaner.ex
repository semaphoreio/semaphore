defmodule Guard.OrganizationCleaner do
  use Quantum, otp_app: :guard

  alias Guard.Store.Organization

  require Logger

  def process do
    Organization.find_candidates_for_hard_destroy()
    |> Enum.each(fn org ->
      Logger.info("Hard destroying organization #{org.id}")
      Organization.hard_destroy(org)
    end)

    :ok
  end
end
