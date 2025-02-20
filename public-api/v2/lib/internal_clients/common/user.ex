defmodule InternalClients.Common.User do
  @moduledoc """
  Module is used for building a user object for responses.
  User object requires a user_id.
  """

  def from_id(id) do
    %PublicAPI.Schemas.Common.User{
      id: id
    }
  end
end
