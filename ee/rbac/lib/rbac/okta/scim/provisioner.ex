defmodule Rbac.Okta.Scim.Provisioner do
  @moduledoc """
  Provisioner creates real users and groups based on okta_users and
  okta_groups where the state is set to pending.

  There are two ways to kick-off the provisioning:

  - Kick it off async (implemented)
  - Wait for the looper to get to the record (NOT implemented)

  The direct kick-off is the primary way in which users are provisioned.
  The looper is a backup solution to handle cases with problems.
  """

  require Logger

  import Ecto.Query
  alias Rbac.Toolbox.{Periodic, Parallel, Duration}
  alias Rbac.Repo.OktaUser

  use Periodic

  def init(_opts) do
    super(%{
      name: "okta_provisioner",
      naptime: Duration.seconds(30),
      timeout: Duration.seconds(60)
    })
  end

  def perform do
    pending = load_pending()

    Watchman.submit("okta.scim.provisioner.pending.count", length(pending))

    pending |> Parallel.in_batches([batch_size: 4], &perform/1)
  end

  def perform(okta_user_id) do
    OktaUser.reload_with_lock_and_transaction(okta_user_id, fn okta_user ->
      cond do
        okta_user.user_id == nil ->
          # A real Semaphore user was not yet created for this Okta account
          Rbac.Okta.Scim.Provisioner.AddUser.run(okta_user)

        OktaUser.active?(okta_user) ->
          # If the user is active, we are simply updating the associated records in the database
          Rbac.Okta.Scim.Provisioner.UpdateUser.run(okta_user)

        not OktaUser.active?(okta_user) ->
          # If the user is not active, we need to deprovision it from the system.
          Rbac.Okta.Scim.Provisioner.DeactivateUser.run(okta_user)
      end
    end)
  end

  defp load_pending do
    import Ecto.Query

    Rbac.Repo.all(
      from(o in OktaUser,
        where:
          o.state == :pending and
            o.updated_at > fragment("now() - interval '1 hour'"),
        select: o.id
      )
    )
  end
end
