defmodule Support.Stubs do
  alias Support.Stubs
  require Logger

  def init do
    if initiated?() do
      do_reset()
    else
      do_init()
    end
  end

  defp do_init do
    Support.FakeServices.init()
    Support.Stubs.DB.init()

    Support.Stubs.User.init()
    Support.Stubs.Feature.init()
    Support.Stubs.RBAC.init()
    Support.Stubs.Organization.init()
    Support.Stubs.Delivery.init()

    :ok
  end

  defp do_reset do
    Support.Stubs.DB.reset()

    :ok
  end

  defp initiated? do
    Process.whereis(Support.Stubs.DB.State) != nil
  end

  def build_shared_factories do
    Support.Stubs.PermissionPatrol.allow_everything()
    Stubs.Feature.seed()

    user = Stubs.User.create_default()

    org =
      Stubs.Organization.create_default(owner_id: user.id)
      |> tap(fn %{id: org_id} ->
        Stubs.Feature.set_org_defaults(org_id)
      end)

    Support.Stubs.RBAC.add_owner(org.id, user.id)
    :ok
  end
end
