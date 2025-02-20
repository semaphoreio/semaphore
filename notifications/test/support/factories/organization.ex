defmodule Support.Factories.Organization do
  def build do
    %InternalApi.Organization.Organization{
      :org_username => "ribizzla",
      :created_at => %Google.Protobuf.Timestamp{
        :seconds => 1
      },
      :avatar_url =>
        "https://storage.googleapis.com/semaphore-design/release-7dcce2b/images/org-r.svg",
      :org_id => Ecto.UUID.generate(),
      :name => "Ribizzla"
    }
  end
end
