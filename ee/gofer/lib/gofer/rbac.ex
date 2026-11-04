defmodule Gofer.RBAC do
  @moduledoc """
  Facade module to interact with RBAC
  """

  alias Gofer.RBAC

  def check_roles(subject = %RBAC.Subject{}, role_ids, opts \\ []) do
    cond do
      Keyword.get(opts, :cached?, false) -> RBAC.RolesCache.check_roles(subject, role_ids)
      Keyword.get(opts, :fresh?, false) -> RBAC.RolesCache.check_roles_fresh(subject, role_ids)
      true -> RBAC.Client.check_roles(subject, role_ids)
    end
  end
end
