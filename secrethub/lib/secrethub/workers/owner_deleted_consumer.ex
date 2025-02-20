defmodule Secrethub.Workers.OwnerDeletedConsumer do
  require Logger

  use Tackle.Multiconsumer,
    url: Application.get_env(:secrethub, :amqp_url),
    service: "secrethub.secret_destroyer",
    routes: [
      {"project_exchange", "deleted", :deleted_project},
      {"organization_exchange", "deleted", :deleted_organization}
    ]

  @metric_name "secret_destroyer.duration"
  @log_prefix "[secret_destroyer] "

  alias Secrethub.OpenIDConnect.JWTConfiguration

  def deleted_project(message) do
    Watchman.benchmark({@metric_name, ["project"]}, fn ->
      event = InternalApi.Projecthub.ProjectDeleted.decode(message)

      log("Processing project: #{event.project_id}")

      {num_of_deleted_secrets, _} =
        try do
          Secrethub.ProjectSecrets.Store.destroy_many(event.project_id)
        rescue
          e ->
            Watchman.increment({@metric_name, ["project", "error"]})
            Logger.error(@log_prefix <> "#{inspect(e)}")
            reraise e, __STACKTRACE__
        end

      log("Deleted #{num_of_deleted_secrets} project secrets for project: #{event.project_id}")

      try do
        JWTConfiguration.delete_project_config(event.org_id, event.project_id)
      rescue
        e ->
          Watchman.increment({@metric_name, ["project", "error"]})
          Logger.error(@log_prefix <> "#{inspect(e)}")
          reraise e, __STACKTRACE__
      end
    end)
  end

  def deleted_organization(message) do
    Watchman.benchmark({@metric_name, ["organization"]}, fn ->
      event = InternalApi.Organization.OrganizationDeleted.decode(message)

      log("Processing: #{event.org_id}")

      {num_of_deleted_secrets, _} =
        try do
          Secrethub.Secret
          |> Secrethub.Secret.in_org(event.org_id)
          |> Secrethub.Repo.delete_all()
        rescue
          e ->
            Watchman.increment({@metric_name, ["organization", "error"]})
            Logger.error(@log_prefix <> "#{inspect(e)}")
            reraise e, __STACKTRACE__
        end

      log("Deleted #{num_of_deleted_secrets} secrets for organization: #{event.org_id}")

      try do
        JWTConfiguration.delete_org_config(event.org_id)
      rescue
        e ->
          Watchman.increment({@metric_name, ["organization", "error"]})
          Logger.error(@log_prefix <> "#{inspect(e)}")
          reraise e, __STACKTRACE__
      end
    end)
  end

  defp log(message), do: Logger.info(@log_prefix <> message)
end
