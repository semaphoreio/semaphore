defmodule Rbac.Store do
  @callback get(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback put(String.t(), String.t(), String.t()) ::
              {:ok, non_neg_integer()} | {:error, String.t()}
  @callback put_batch(String.t(), list(String.t()), list(String.t()), Keyword.t()) ::
              {:ok, non_neg_integer()} | {:error, String.t()}
  @callback delete(String.t(), list(String.t())) ::
              {:ok, non_neg_integer()} | {:error, String.t()}
  @callback clear(String.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
end
