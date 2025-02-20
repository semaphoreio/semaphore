defmodule Zebra.Workers.JobRequestFactory.JobRequest do
  @sanitized "{SANITIZED}"

  def env_var(name, nil) do
    %{"name" => name, "value" => ""}
  end

  def env_var(name, value, options \\ []) do
    defaults = [encode_to_base64: true]
    options = Keyword.merge(defaults, options)

    base64_encoded_value =
      if Keyword.get(options, :encode_to_base64) do
        Base.encode64(value)
      else
        value
      end

    %{"name" => name, "value" => base64_encoded_value}
  end

  def file(path, content, mode, options \\ []) do
    defaults = [encode_to_base64: true]
    options = Keyword.merge(defaults, options)

    base64_encoded_content =
      if Keyword.get(options, :encode_to_base64) do
        Base.encode64(content)
      else
        content
      end

    %{"path" => path, "content" => base64_encoded_content, "mode" => mode}
  end

  def command(directive) do
    %{"directive" => directive}
  end

  def command(directive, alias_name) do
    %{"directive" => directive, "alias" => alias_name}
  end

  def ssh_public_keys(nil), do: []

  def ssh_public_keys(rsa) do
    [
      Base.encode64(rsa.public_key)
    ]
  end

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def encode(
        agent,
        ssh_public_keys,
        job,
        commands,
        epilogue,
        env_vars,
        files,
        all_secrets,
        callback_token
      ) do
    request = %{
      "job_id" => job.id,
      "job_name" => job.name,
      "ssh_public_keys" => ssh_public_keys,
      "files" => files,
      "env_vars" => env_vars,
      "commands" => commands,
      "epilogue_always_commands" => epilogue.always_commands,
      "epilogue_on_pass_commands" => epilogue.on_pass,
      "epilogue_on_fail_commands" => epilogue.on_fail,
      "callbacks" => %{
        "finished" => callback("finished", job.id),
        "teardown_finished" => callback("teardown_finished", job.id),
        "token" => callback_token
      }
    }

    if agent.containers != [] do
      Map.merge(request, %{
        "executor" => "dockercompose",
        "compose" => encode_compose(agent, all_secrets)
      })
    else
      request
    end
  end

  def append_logger(request, job, org_url, token) do
    if Zebra.Models.Job.self_hosted?(job.machine_type) do
      Map.merge(request, %{
        "logger" => %{
          "method" => "push",
          "url" => "#{org_url}/api/v1/logs/#{job.id}",
          "token" => token
        }
      })
    else
      Map.merge(request, %{
        "logger" => %{
          "method" => "pull"
        }
      })
    end
  end

  def encode_compose(agent_spec, all_secrets) do
    containers =
      agent_spec.containers
      |> Enum.with_index()
      |> Enum.map(fn {c, i} -> encode_container(c, i, all_secrets) end)

    image_pull_credentials =
      Enum.map(all_secrets.image_pull_secrets, fn s ->
        %{
          "env_vars" => s.env_vars,
          "files" => s.files
        }
      end)

    %{
      "containers" => containers,
      "image_pull_credentials" => image_pull_credentials,
      "host_setup_commands" => []
    }
  end

  def encode_container(container_spec, index, all_secrets) do
    secrets = Enum.at(all_secrets.container_secrets, index)

    env_vars =
      Enum.flat_map(secrets, & &1.env_vars) ++
        Enum.map(container_spec.env_vars, fn e ->
          env_var(e.name, e.value)
        end)

    files = Enum.flat_map(secrets, & &1.files)

    %{
      "name" => container_spec.name,
      "image" => redirect_semaphoreci_convenient_images(container_spec.image),
      "command" => container_spec.command,
      "env_vars" => env_vars,
      "files" => files
    }
  end

  def sanitized?(nil), do: true

  def sanitized?(request) do
    env_vars =
      if Map.has_key?(request, "env_vars"),
        do: request["env_vars"],
        else: request["environment_variables"]

    if env_vars == nil do
      true
    else
      Enum.any?(env_vars, fn env_var ->
        env_var["value"] == @sanitized || env_var["unencrypted_content"] == @sanitized
      end)
    end
  end

  def sanitize(nil), do: nil

  def sanitize(request) do
    request
    |> sanitize_if_present("env_vars", fn v -> sanitize_env_vars(v) end)
    |> sanitize_if_present("environment_variables", fn v -> sanitize_env_vars(v) end)
    |> sanitize_if_present("files", fn v -> sanitize_files(v) end)
    |> sanitize_if_present("custom_files", fn v -> sanitize_files(v) end)
    |> sanitize_if_present("compose", fn v -> sanitize_compose(v) end)
    |> sanitize_if_present("ssh_public_keys", fn v -> sanitize_keys(v) end)
    |> sanitize_if_present("logger", fn v -> sanitize_logger(v) end)
    |> sanitize_if_present("callbacks", fn v -> sanitize_callbacks(v) end)
  end

  def sanitize_if_present(request, field, func) do
    if Map.has_key?(request, field) do
      Map.put(request, field, func.(request[field]))
    else
      request
    end
  end

  defp sanitize_callbacks(callbacks = %{"token" => _}) do
    Map.merge(callbacks, %{"token" => @sanitized})
  end

  defp sanitize_callbacks(callbacks), do: callbacks

  defp sanitize_logger(logger = %{"method" => "push"}) do
    %{
      "method" => logger["method"],
      "url" => logger["url"],
      "token" => @sanitized
    }
  end

  defp sanitize_logger(logger), do: logger

  defp sanitize_keys(nil), do: nil
  defp sanitize_keys([]), do: []

  defp sanitize_keys(keys) do
    Enum.map(keys, fn _key -> @sanitized end)
  end

  defp sanitize_env_vars(nil), do: nil

  defp sanitize_env_vars(env_vars) do
    env_vars
    |> Enum.map(fn env_var ->
      if sensitive_env_var?(env_var["name"]) do
        sanitize_env_var(env_var)
      else
        env_var
      end
    end)
  end

  # When sanitizing old requests, we should keep the same old structure, instead of mixing the two.
  defp sanitize_env_var(%{"unencrypted_content" => _, "name" => name}) do
    %{
      "name" => name,
      "encoding" => "base64",
      "unencrypted_content" => @sanitized
    }
  end

  defp sanitize_env_var(%{"value" => _, "name" => name}) do
    env_var(name, @sanitized, encode_to_base64: false)
  end

  defp sensitive_env_var?(name) do
    cond do
      # Some env vars not prefixed with SEMAPHORE are not sensitive and included by us.
      name in ["CI", "DISPLAY", "PAGER", "SSH_PRIVATE_KEY_PATH", "TERM"] ->
        false

      # All other env vars that are not prefixed with SEMAPHORE are sensitive.
      not String.starts_with?(name, "SEMAPHORE") ->
        true

      # Some SEMAPHORE prefixed env vars are also sensitive
      name in ["SEMAPHORE_OIDC_TOKEN", "SEMAPHORE_ARTIFACT_TOKEN", "SEMAPHORE_CACHE_USERNAME"] ->
        true

      # Everything else is not sensitive
      true ->
        false
    end
  end

  defp sanitize_files(nil), do: nil

  defp sanitize_files(files) do
    files
    |> Enum.map(fn file ->
      cond do
        !is_map(file) ->
          file

        Map.has_key?(file, "unencrypted_content") ->
          %{
            "path" => file["path"],
            "unencrypted_content" => @sanitized,
            "mode" => file["mode"],
            "encoding" => "base64"
          }

        true ->
          file(file["path"], @sanitized, file["mode"], encode_to_base64: false)
      end
    end)
  end

  defp sanitize_compose(
         compose = %{
           "containers" => containers,
           "image_pull_credentials" => credentials
         }
       ) do
    %{
      compose
      | "containers" => sanitize_containers(containers),
        "image_pull_credentials" => sanitize_image_pull_credentials(credentials)
    }
  end

  defp sanitize_compose(compose), do: compose

  defp sanitize_containers(nil), do: nil

  defp sanitize_containers(containers) do
    Enum.map(containers, fn container ->
      %{
        container
        | "env_vars" => sanitize_env_vars(container["env_vars"]),
          "files" => sanitize_files(container["files"])
      }
    end)
  end

  defp sanitize_image_pull_credentials(nil), do: nil

  defp sanitize_image_pull_credentials(credentials) do
    Enum.map(credentials, fn credential ->
      %{
        "env_vars" => sanitize_env_vars(credential["env_vars"]),
        "files" => sanitize_files(credential["files"])
      }
    end)
  end

  #
  # On November 1st 2020, DockerHub introduced rate limits for pulling Docker
  # images. To combat this, we prepared a list of Docker images that are
  # officially supported by Semaphore.
  #
  # Previously, these images were hosted on DockerHub under the semaphoreci
  # organization. Now, they are hosted under registry.semaphoreci.com Docker
  # registry that we maintain and host.
  #
  # To avoid the need to contact each customer and ask them to change their YAML
  # configuration images:
  #
  # - from 'semaphoreci/<image>'
  # - to   'registry.semaphoreci.com/<image>'
  #
  # we are going to do this programmatically for them.
  #
  def redirect_semaphoreci_convenient_images(image) do
    if String.starts_with?(image, "semaphoreci/") do
      String.replace(image, ~r/^(semaphoreci\/)/, "registry.semaphoreci.com/")
    else
      # don't modify images that are not ours
      image
    end
  end

  def callback(type, id) do
    "https://#{Zebra.Config.fetch!(Zebra.Workers.JobRequestFactory, :broker_url)}/#{type}/#{id}"
  end
end
