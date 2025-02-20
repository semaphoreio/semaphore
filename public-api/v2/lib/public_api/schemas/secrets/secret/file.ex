defmodule PublicAPI.Schemas.Secrets.Secret.File do
  @moduledoc """
  Schema for a secret file
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    type: :object,
    title: "Secrets.Secret.File",
    description: "File",
    properties: %{
      path: %Schema{
        type: :string,
        minLength: 1,
        example: "/path/to/file",
        description: "Name of the file. Both absolute and relative paths are allowed."
      },
      content: %Schema{
        type: :string,
        description: "base64 encoded content of the file or a md5 checksum"
      }
    },
    required: [:path, :content]
  })
end
