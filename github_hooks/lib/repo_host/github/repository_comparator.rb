# frozen_string_literal: true

module RepoHost::Github
  class RepositoryComparator
    def initialize(repository, payload)
      @repository = repository
      @payload = payload
    end

    def different?
      changes.values.any? { |values| values.size > 1 }
    end

    def changes
      @changes ||= {
        :name_changed => unique_values(database_full_name, payload_full_name),
        :default_branch_changed => unique_values(repository.default_branch, payload_default_branch)
      }
    end

    private

    attr_reader :repository, :payload

    def database_full_name
      [repository.owner, repository.name].compact.join("/")
    end

    def payload_full_name
      payload["full_name"]
    end

    def payload_default_branch
      payload["default_branch"]
    end

    def unique_values(*values)
      values.compact.uniq
    end
  end
end
