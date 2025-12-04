# frozen_string_literal: true

module RepoHost::Github
  class RepositoryComparator
    def initialize(repository, payload)
      @repository = repository
      @payload = payload
    end

    def different?
      changes.value?(true)
    end

    def changes
      {
        :name_changed => name_changed?,
        :default_branch_changed => default_branch_changed?
      }
    end

    private

    attr_reader :repository, :payload

    def name_changed?
      "#{repository.owner}/#{repository.name}" != payload["full_name"]
    end

    def default_branch_changed?
      repository.default_branch != payload["default_branch"]
    end
  end
end
