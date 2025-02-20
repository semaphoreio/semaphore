defmodule Support.FakeServices.UserService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.User.UserService.Service

  def describe(req, stream) do
    FunRegistry.run!(__MODULE__, :describe, [req, stream])
  end

  def describe_many(req, stream) do
    FunRegistry.run!(__MODULE__, :describe_many, [req, stream])
  end

  def update(req, stream) do
    FunRegistry.run!(__MODULE__, :update, [req, stream])
  end

  def regenerate_token(req, stream) do
    FunRegistry.run!(__MODULE__, :regenerate_token, [req, stream])
  end

  def list_favorites(req, stream) do
    FunRegistry.run!(__MODULE__, :list_favorites, [req, stream])
  end

  def create_favorite(req, stream) do
    FunRegistry.run!(__MODULE__, :create_favorite, [req, stream])
  end

  def delete_favorite(req, stream) do
    FunRegistry.run!(__MODULE__, :delete_favorite, [req, stream])
  end

  def check_github_token(req, stream) do
    FunRegistry.run!(__MODULE__, :check_github_token, [req, stream])
  end
end
