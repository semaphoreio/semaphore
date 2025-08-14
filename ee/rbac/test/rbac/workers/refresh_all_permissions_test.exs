defmodule Rbac.Workers.RefreshAllPermissionsTest do
  use Rbac.RepoCase, async: false

  import Mock
  alias Rbac.Store.UserPermissions
  alias Rbac.Workers.RefreshAllPermissions, as: Worker
  alias Rbac.Repo.RbacRefreshAllPermissionsRequest, as: Request

  @number_of_orgs 70

  describe "perform/1" do
    setup do
      {:ok, worker} = Worker.start_link()
      on_exit(fn -> Process.exit(worker, :kill) end)

      Request.create_new_request()
      :ok
    end

    test "When request is successfully processed" do
      org_ids = Enum.map(1..@number_of_orgs, fn _ -> Ecto.UUID.generate() end)

      with_mocks([
        {Rbac.FrontRepo, [:passthrough], [all: fn _ -> org_ids end]},
        {Rbac.RoleBindingIdentification, [], [new: fn _ -> {:ok, %{}} end]},
        {UserPermissions, [], [add_permissions: fn _ -> :ok end]}
      ]) do
        work()
        req = load_request()

        assert req.state == :done
        assert req.organizations_updated == @number_of_orgs

        assert_called_exactly(UserPermissions.add_permissions(:_), @number_of_orgs)
      end
    end

    @max_retries 3
    test "When request is not successfully processed" do
      org_ids = Enum.map(1..@number_of_orgs, fn _ -> Ecto.UUID.generate() end)

      with_mocks([
        {Rbac.FrontRepo, [:passthrough], [all: fn _ -> org_ids end]},
        {Rbac.RoleBindingIdentification, [], [new: fn _ -> raise "error" end]}
      ]) do
        work()
        assert_called_exactly(Rbac.RoleBindingIdentification.new(:_), @max_retries)
      end

      req = load_request()

      assert req.state == :failed
      assert req.retries == @max_retries
      assert req.organizations_updated == 0
    end
  end

  defp load_request do
    Request |> Rbac.Repo.one()
  end

  defp work do
    Worker.perform_now()
    :timer.sleep(500)
  end
end
