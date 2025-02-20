defmodule Support.Factories.Project do
  def build do
    %InternalApi.Projecthub.Project{
      :metadata => %InternalApi.Projecthub.Project.Metadata{
        :name => "test-repo",
        :id => Ecto.UUID.generate(),
        :owner_id => Ecto.UUID.generate(),
        :org_id => Ecto.UUID.generate()
      },
      :spec => %InternalApi.Projecthub.Project.Spec{
        :repository => %InternalApi.Projecthub.Project.Spec.Repository{
          :url => "git@github.com:test/test-repo.git"
        }
      }
    }
  end
end
