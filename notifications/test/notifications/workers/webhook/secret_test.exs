defmodule Notifications.Workers.Webhook.Secret.Test do
  use Notifications.DataCase

  alias Notifications.Workers.Webhook.Secret

  setup do
    org_id = ""
    secret_name = "foo"

    [
      org_id: org_id,
      secret_name: secret_name
    ]
  end

  describe ".get" do
    test "when secret name is empty => returns nil", %{org_id: org_id} do
      assert Secret.get(org_id, "") == {:ok, nil}
      assert Secret.get(org_id, nil) == {:ok, nil}
    end

    test "when secret can't be found => returns nil", %{org_id: org_id, secret_name: secret_name} do
      SecretMock
      |> GrpcMock.expect(:describe, fn _, _ ->
        InternalApi.Secrethub.DescribeResponse.new(
          metadata:
            InternalApi.Secrethub.ResponseMeta.new(
              status: InternalApi.Secrethub.ResponseMeta.Status.new(code: :NOT_FOUND)
            )
        )
      end)

      assert Secret.get(org_id, secret_name) == {:ok, nil}

      GrpcMock.verify!(SecretMock)
    end

    test "when env var can't be found => returns nil", %{org_id: org_id, secret_name: secret_name} do
      SecretMock
      |> GrpcMock.expect(:describe, fn _, _ ->
        InternalApi.Secrethub.DescribeResponse.new(
          metadata:
            InternalApi.Secrethub.ResponseMeta.new(
              status: InternalApi.Secrethub.ResponseMeta.Status.new(code: :OK)
            ),
          secret:
            InternalApi.Secrethub.Secret.new(
              data: InternalApi.Secrethub.Secret.Data.new(env_vars: [])
            )
        )
      end)

      assert Secret.get(org_id, secret_name) == {:ok, nil}

      GrpcMock.verify!(SecretMock)
    end

    test "when found => returns secret", %{org_id: org_id, secret_name: secret_name} do
      SecretMock
      |> GrpcMock.expect(:describe, fn _, _ ->
        InternalApi.Secrethub.DescribeResponse.new(
          metadata:
            InternalApi.Secrethub.ResponseMeta.new(
              status: InternalApi.Secrethub.ResponseMeta.Status.new(code: :OK)
            ),
          secret:
            InternalApi.Secrethub.Secret.new(
              data:
                InternalApi.Secrethub.Secret.Data.new(
                  env_vars: [
                    InternalApi.Secrethub.Secret.EnvVar.new(
                      name: "WEBHOOK_SECRET",
                      value: "foo_secret"
                    )
                  ]
                ),
              dt_config: nil,
              metadata: InternalApi.Secrethub.Secret.Metadata.new(level: :ORGANIZATION),
              org_config:
                InternalApi.Secrethub.Secret.OrgConfig.new(
                  attach_access: :JOB_ATTACH_YES,
                  debug_access: :JOB_DEBUG_YES,
                  project_ids: [],
                  projects_access: :ALL
                ),
              project_config: nil
            )
        )
      end)

      assert Secret.get(org_id, secret_name) == {:ok, "foo_secret"}

      GrpcMock.verify!(SecretMock)
    end
  end
end
