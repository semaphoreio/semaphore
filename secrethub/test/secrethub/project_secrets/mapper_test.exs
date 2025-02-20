defmodule Secrethub.ProjectSecrets.MapperTest do
  use ExUnit.Case, async: true

  alias InternalApi.Secrethub, as: API
  alias Secrethub.ProjectSecrets.Mapper
  alias Secrethub.ProjectSecrets.Secret
  alias Secrethub.Model

  setup_all [
    :prepare_data,
    :prepare_checkout,
    :prepare_content,
    :prepare_secret,
    :prepare_params
  ]

  describe "encode/1" do
    test "encodes basic fields as metadata", ctx do
      assert %API.Secret{metadata: metadata} = Mapper.encode(ctx.secret)
      epoch_time = DateTime.to_unix(ctx.now)

      assert metadata.id == ctx.secret.id
      assert metadata.name == ctx.secret.name
      assert metadata.org_id == ctx.secret.org_id
      assert metadata.created_by == ctx.secret.created_by
      assert metadata.updated_by == ctx.secret.updated_by
      assert metadata.created_at.seconds == epoch_time
      assert metadata.updated_at.seconds == epoch_time
      assert metadata.level == :PROJECT
    end

    test "encodes project ID in a config", ctx = %{project_id: project_id} do
      assert %API.Secret{project_config: %API.Secret.ProjectConfig{project_id: ^project_id}} =
               Mapper.encode(ctx.secret)
    end

    test "when used_by is not present then maps it as nil", ctx do
      assert %API.Secret{metadata: %API.Secret.Metadata{last_checkout: nil}} =
               Mapper.encode(%{ctx.secret | used_by: nil})
    end

    test "when used_by is present then maps it correctly", ctx do
      assert %API.Secret{metadata: %API.Secret.Metadata{last_checkout: checkout}} =
               Mapper.encode(ctx.secret)

      for field <- ~w(job_id pipeline_id workflow_id hook_id project_id user_id)a,
          do: assert(Map.get(checkout, field) == Map.get(ctx.checkout, field))
    end

    test "when used_at is not present then maps it as nil", ctx do
      assert %API.Secret{metadata: %API.Secret.Metadata{checkout_at: nil}} =
               Mapper.encode(%{ctx.secret | used_at: nil})
    end

    test "when used_at is present then maps it correctly", ctx do
      assert %API.Secret{metadata: %API.Secret.Metadata{checkout_at: checkout_at}} =
               Mapper.encode(ctx.secret)

      assert checkout_at.seconds == DateTime.to_unix(ctx.now)
    end

    test "maps content to data", ctx do
      assert %API.Secret{data: %API.Secret.Data{env_vars: env_vars, files: files}} =
               Mapper.encode(ctx.secret)

      assert Enum.into(env_vars, %{}, &{&1.name, &1.value}) ==
               Enum.into(ctx.content.env_vars, %{}, &{&1.name, &1.value})

      assert Enum.into(files, %{}, &{&1.path, &1.content}) ==
               Enum.into(ctx.content.files, %{}, &{&1.path, &1.content})
    end
  end

  describe "decode/1" do
    test "encodes basic fields as metadata", ctx do
      expected = %{
        id: ctx.params.metadata.id,
        name: ctx.params.metadata.name,
        org_id: ctx.params.metadata.org_id,
        project_id: ctx.params.project_config.project_id,
        created_by: ctx.params.metadata.created_by,
        updated_by: ctx.params.metadata.updated_by,
        content: %{
          env_vars: [%{name: "ENV_VAR", value: "value"}],
          files: [%{path: "/home/path", content: "content"}]
        }
      }

      assert expected == Mapper.decode(ctx.params)
    end

    test "when field is empty string then omits it", ctx do
      for field <- ~w(id name org_id created_by updated_by)a do
        refute %{ctx.params | metadata: Map.delete(ctx.params.metadata, field)}
               |> Mapper.decode()
               |> Map.has_key?(field)
      end

      refute %{ctx.params | project_config: nil}
             |> Mapper.decode()
             |> Map.has_key?(:project_id)

      refute %{ctx.params | project_config: API.Secret.ProjectConfig.new()}
             |> Mapper.decode()
             |> Map.has_key?(:project_id)
    end

    test "when content is empty then omits it", ctx do
      refute %{ctx.params | data: nil}
             |> Mapper.decode()
             |> Map.has_key?(:content)

      assert %{ctx.params | data: API.Secret.Data.new()}
             |> Mapper.decode()
             |> Map.has_key?(:content)

      assert %{ctx.params | data: API.Secret.Data.new()}
             |> Mapper.decode()
             |> Map.get(:content)
             |> Map.values()
             |> Enum.all?(&Enum.empty?/1)
    end
  end

  defp prepare_data(_context) do
    {:ok,
     project_id: Ecto.UUID.generate(),
     org_id: Ecto.UUID.generate(),
     user_id: Ecto.UUID.generate(),
     now: DateTime.utc_now(),
     epoch: DateTime.utc_now() |> DateTime.to_unix()}
  end

  defp prepare_checkout(_context) do
    {:ok,
     checkout: %Model.Checkout{
       job_id: Ecto.UUID.generate(),
       pipeline_id: Ecto.UUID.generate(),
       workflow_id: Ecto.UUID.generate(),
       hook_id: Ecto.UUID.generate(),
       project_id: Ecto.UUID.generate(),
       user_id: Ecto.UUID.generate()
     }}
  end

  defp prepare_content(_context) do
    {:ok,
     content: %Model.Content{
       env_vars: [
         %Model.EnvVar{name: "NAME1", value: "value1"},
         %Model.EnvVar{name: "NAME2", value: "value2"},
         %Model.EnvVar{name: "NAME3", value: "value3"}
       ],
       files: [
         %Model.File{path: "/home/path1", content: "content1"},
         %Model.File{path: "/home/path2", content: "content2"},
         %Model.File{path: "/home/path3", content: "content3"}
       ]
     }}
  end

  defp prepare_secret(context) do
    name = "dt.#{context.project_id}"

    case Secrethub.Encryptor.encrypt(Poison.encode!(context.content), name) do
      {:ok, encrypted} ->
        {:ok,
         secret: %Secret{
           id: Ecto.UUID.generate(),
           name: "dt.#{context.project_id}",
           project_id: context.project_id,
           org_id: context.org_id,
           created_by: context.user_id,
           updated_by: context.user_id,
           used_at: context.now,
           used_by: context.checkout,
           content: context.content,
           content_encrypted: encrypted,
           inserted_at: context.now |> DateTime.to_naive(),
           updated_at: context.now |> DateTime.to_naive()
         }}
    end
  end

  defp prepare_params(ctx) do
    {:ok,
     params:
       API.Secret.new(
         metadata:
           API.Secret.Metadata.new(
             id: Ecto.UUID.generate(),
             name: "dt.#{ctx.project_id}",
             org_id: ctx.org_id,
             level: :PROJECT,
             created_by: ctx.user_id,
             updated_by: Ecto.UUID.generate(),
             last_checkout:
               API.CheckoutMetadata.new(
                 job_id: Ecto.UUID.generate(),
                 pipeline_id: Ecto.UUID.generate(),
                 workflow_id: Ecto.UUID.generate(),
                 hook_id: Ecto.UUID.generate(),
                 project_id: Ecto.UUID.generate(),
                 user_id: Ecto.UUID.generate()
               ),
             created_at: Google.Protobuf.Timestamp.new(seconds: ctx.epoch),
             updated_at: Google.Protobuf.Timestamp.new(seconds: ctx.epoch),
             checkout_at: Google.Protobuf.Timestamp.new(seconds: ctx.epoch)
           ),
         data:
           API.Secret.Data.new(
             env_vars: [
               API.Secret.EnvVar.new(
                 name: "ENV_VAR",
                 value: "value"
               )
             ],
             files: [
               API.Secret.File.new(
                 path: "/home/path",
                 content: "content"
               )
             ]
           ),
         project_config: API.Secret.ProjectConfig.new(project_id: ctx.project_id)
       )}
  end
end
