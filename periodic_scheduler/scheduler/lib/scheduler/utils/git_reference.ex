defmodule Scheduler.Utils.GitReference do
  @moduledoc """
  Utilities for handling Git reference normalization and conversion.

  Git references can come in various formats:
  - Branch names: "master", "develop", "feature-branch"
  - Full branch refs: "refs/heads/master", "refs/heads/develop"
  - Tag refs: "refs/tags/v1.0.0", "refs/tags/release"
  - PR refs: "refs/pull/123/head"
  """

  @doc """
  Normalizes a git reference to its full form.

  ## Examples

      iex> Scheduler.Utils.GitReference.normalize("master")
      "refs/heads/master"

      iex> Scheduler.Utils.GitReference.normalize("refs/heads/master")
      "refs/heads/master"

      iex> Scheduler.Utils.GitReference.normalize("refs/tags/v1.0.0")
      "refs/tags/v1.0.0"

      iex> Scheduler.Utils.GitReference.normalize("refs/pull/123/head")
      "refs/pull/123/head"
  """
  def normalize(reference) when is_binary(reference) do
    cond do
      String.starts_with?(reference, "refs/") ->
        # Already a full reference
        reference

      true ->
        # Assume it's a branch name and add refs/heads/ prefix
        "refs/heads/" <> reference
    end
  end

  def normalize(nil), do: nil

  @doc """
  Extracts the short name from a full git reference.

  ## Examples

      iex> Scheduler.Utils.GitReference.extract_name("refs/heads/master")
      "master"

      iex> Scheduler.Utils.GitReference.extract_name("refs/tags/v1.0.0")
      "v1.0.0"

      iex> Scheduler.Utils.GitReference.extract_name("refs/pull/123/head")
      "123/head"

      iex> Scheduler.Utils.GitReference.extract_name("feature-branch")
      "feature-branch"
  """
  def extract_name(reference) when is_binary(reference) do
    cond do
      String.starts_with?(reference, "refs/heads/") ->
        String.replace_prefix(reference, "refs/heads/", "")

      String.starts_with?(reference, "refs/tags/") ->
        String.replace_prefix(reference, "refs/tags/", "")

      String.starts_with?(reference, "refs/pull/") ->
        String.replace_prefix(reference, "refs/pull/", "")

      true ->
        # Not a full reference, return as-is
        reference
    end
  end

  def extract_name(nil), do: nil

  @doc """
  Builds a full git reference from type and name.

  ## Examples

      iex> Scheduler.Utils.GitReference.build_full_reference("BRANCH", "master")
      "refs/heads/master"

      iex> Scheduler.Utils.GitReference.build_full_reference("TAG", "v1.0.0")
      "refs/tags/v1.0.0"

      iex> Scheduler.Utils.GitReference.build_full_reference("PR", "123")
      "refs/pull/123/head"

      iex> Scheduler.Utils.GitReference.build_full_reference("UNKNOWN", "something")
      "something"
  """
  def build_full_reference("BRANCH", name), do: "refs/heads/" <> name
  def build_full_reference("TAG", name), do: "refs/tags/" <> name
  def build_full_reference("PR", name), do: "refs/pull/" <> name <> "/head"
  def build_full_reference(_unknown_type, name), do: name

  @doc """
  Determines the type of git reference.

  ## Examples

      iex> Scheduler.Utils.GitReference.get_type("refs/heads/master")
      :branch

      iex> Scheduler.Utils.GitReference.get_type("refs/tags/v1.0.0")
      :tag

      iex> Scheduler.Utils.GitReference.get_type("refs/pull/123/head")
      :pull_request

      iex> Scheduler.Utils.GitReference.get_type("master")
      :branch

      iex> Scheduler.Utils.GitReference.get_type("refs/invalid")
      :branch
  """
  def get_type(reference) when is_binary(reference) do
    cond do
      String.starts_with?(reference, "refs/heads/") -> :branch
      String.starts_with?(reference, "refs/tags/") -> :tag
      String.starts_with?(reference, "refs/pull/") -> :pull_request
      true -> :branch
    end
  end

  def get_type(nil), do: nil
end
