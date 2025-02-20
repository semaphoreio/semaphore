defmodule Support.Stubs.RBAC do
  alias Support.Stubs.RBAC, as: Stub
  import ExUnit.Callbacks
  use Agent

  @mock RBACMock

  def setup() do
    start_supervised!(__MODULE__)

    Stub.Grpc.init(@mock)
    GRPC.Server.start(@mock, 51_051)

    on_exit(fn ->
      GRPC.Server.stop(@mock)
    end)
  end

  def setdown() do
    GRPC.Server.stop(@mock)

    on_exit(fn ->
      GRPC.Server.start(@mock, 50_051)
      Stub.Grpc.init(@mock)
    end)
  end

  def start_link(_args) do
    Agent.start_link(fn -> :ets.new(__MODULE__, [:bag, :protected, :named_table]) end,
      name: __MODULE__
    )
  end

  def flush_org(org_id) do
    Agent.cast(__MODULE__, fn _tid ->
      :ets.delete(__MODULE__, org_id)
    end)
  end

  def set_role(role = {_org_id, _proj_id, _user_id, _role_id}) do
    Agent.cast(__MODULE__, fn _tid ->
      :ets.insert(__MODULE__, role)
    end)
  end

  def remove_role(role = {_org_id, _proj_id, _user_id, _role_id}) do
    Agent.cast(__MODULE__, fn _tid ->
      :ets.delete_object(__MODULE__, role)
    end)
  end

  defmodule Grpc do
    alias InternalApi.RBAC, as: API

    def init(mock) do
      GrpcMock.stub(mock, :subjects_have_roles, &__MODULE__.subjects_have_roles/2)
    end

    def subjects_have_roles(request = %API.SubjectsHaveRolesRequest{}, _stream) do
      has_roles =
        for role_assignment <- request.role_assignments do
          API.SubjectsHaveRolesResponse.HasRole.new(
            has_role: exists?(role_assignment),
            role_assignment: role_assignment
          )
        end

      API.SubjectsHaveRolesResponse.new(has_roles: has_roles)
    end

    defp exists?(role), do: length(:ets.match(Support.Stubs.RBAC, to_ets_record(role))) > 0

    defp to_ets_record(asgn = %API.RoleAssignment{}),
      do: {asgn.org_id, asgn.project_id, asgn.subject.subject_id, asgn.role_id}
  end

  defmodule Helpers do
    alias Support.Stubs.RBAC, as: RBACStub

    def set_invalid_url() do
      old_config = Application.get_env(:gofer, Gofer.RBAC.Client, [])

      new_config =
        old_config
        |> Keyword.put(:endpoint, "invalid:49999")
        |> Keyword.put(:timeout, 1_000)

      Application.put_env(:gofer, Gofer.RBAC.Client, new_config)
      on_exit(fn -> Application.put_env(:gofer, Gofer.RBAC.Client, old_config) end)
    end

    def set_timeout() do
      old_config = Application.get_env(:gofer, Gofer.RBAC.Client, [])
      new_config = Keyword.put(old_config, :timeout, 1_000)

      Application.put_env(:gofer, Gofer.RBAC.Client, new_config)

      GrpcMock.expect(RBACMock, :subjects_have_roles, fn _, _ ->
        Process.sleep(3_000)

        InternalApi.RBAC.SubjectsHaveRolesResponse.new(
          status: InternalApi.ResponseStatus.new(),
          has_roles: []
        )
      end)

      on_exit(fn ->
        RBACStub.Grpc.init(RBACMock)
        Application.put_env(:gofer, Gofer.RBAC.Client, old_config)
      end)
    end
  end
end
