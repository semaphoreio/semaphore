defmodule RepositoryHub.WebhookEncryptor do
  use Supervisor
  alias RepositoryHub.WebhookEncryptor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    children = [
      WebhookEncryptor.BroadcastProducer,
      WebhookEncryptor.FeatureFilter,
      WebhookEncryptor.ProjectSplitter,
      WebhookEncryptor.TokenEnricher,
      WebhookEncryptor.WorkerSupervisor,
      WebhookEncryptor.WorkerConsumer
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
