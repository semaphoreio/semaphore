defmodule Support.Stubs.Repository do
  alias InternalApi.Repository, as: IAR

  def commit_response_sha, do: "92cda7eb0594ef7916398cd15ab70086368c95fa"

  def init do
    __MODULE__.Grpc.init()
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(
        RepositoryMock,
        :list_accessible_repositories,
        &__MODULE__.list_accessible_repositories/2
      )

      GrpcMock.stub(RepositoryMock, :get_files, &__MODULE__.get_files/2)
      GrpcMock.stub(RepositoryMock, :commit, &__MODULE__.commit/2)
    end

    def list_accessible_repositories(req, _) do
      repositories =
        for i <- 1..100 do
          repo = remote_repository()

          %{
            repo
            | name: "#{repo.name}_#{i}",
              full_name: "renderedtext/front_#{i}",
              addable: rem(i, 10) != 0
          }
        end

      {repos_to_return, next_token} =
        case req.page_token do
          "" -> {Enum.slice(repositories, 0..49), "second_page"}
          "null" -> {Enum.slice(repositories, 0..49), "second_page"}
          "second_page" -> {Enum.slice(repositories, 50..100), ""}
          _ -> {[], ""}
        end

      IAR.ListAccessibleRepositoriesResponse.new(
        repositories: [remote_repository(), repo_with_existing_project()] ++ repos_to_return,
        next_page_token: next_token
      )
    end

    def get_files(_req, _) do
      require Logger

      edition = if System.get_env("OS") == "true", do: "os", else: "saas"

      files =
        File.ls!("test/fixture/yamls/#{edition}")
        |> Enum.map(fn file ->
          IAR.File.new(
            path: ".semaphore/#{file}",
            content: File.read!("test/fixture/yamls/#{edition}/#{file}")
          )
        end)

      Logger.debug("Files: #{inspect(files)}")

      IAR.GetFilesResponse.new(files: files)
    end

    def commit(_req, _) do
      IAR.CommitResponse.new(
        revision: IAR.Revision.new(commit_sha: Support.Stubs.Repository.commit_response_sha())
      )
    end

    defp remote_repository do
      IAR.RemoteRepository.new(
        id: "",
        name: "front",
        description: "",
        url: "",
        full_name: "renderedtext/front",
        addable: true,
        reason: ""
      )
    end

    defp repo_with_existing_project do
      IAR.RemoteRepository.new(
        id: "",
        name: "test",
        description: "",
        url: "git@github.com:test/test.git",
        full_name: "test/test",
        addable: true,
        reason: ""
      )
    end
  end
end
