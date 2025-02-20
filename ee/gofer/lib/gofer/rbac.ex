defmodule Gofer.RBAC do
  @moduledoc """
  Facade module to interact with RBAC
  """

  alias Gofer.RBAC

  def check_roles(subject = %RBAC.Subject{}, role_ids, opts \\ []) do
    if Keyword.get(opts, :cached?, false),
      do: RBAC.RolesCache.check_roles(subject, role_ids),
      else: RBAC.Client.check_roles(subject, role_ids)
  end
end
