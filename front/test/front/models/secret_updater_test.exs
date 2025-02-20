defmodule Front.Models.SecretUpdaterTest do
  use ExUnit.Case, async: true

  alias Front.Models.ConfigFile
  alias Front.Models.EnvironmentVariable
  alias Front.Models.SecretUpdater

  setup do
    {:ok,
     secret: %{
       env_vars: [
         env_var(name: "EV1", value: random_value(), md5: random_md5()),
         env_var(name: "EV2", value: random_value(), md5: random_md5()),
         env_var(name: "EV3", value: random_value(), md5: random_md5())
       ],
       files: [
         cfg_file(path: "/home/path1", content: random_content(), md5: random_md5()),
         cfg_file(path: "/home/path2", content: random_content(), md5: random_md5()),
         cfg_file(path: "/home/path3", content: random_content(), md5: random_md5())
       ]
     }}
  end

  describe "consolidate/3" do
    test "updates env vars and files", %{secret: secret} do
      [
        %EnvironmentVariable{name: existing_name, md5: existing_var_md5, value: existing_value}
        | _
      ] = secret.env_vars

      random_value = random_value()

      env_var_params = [
        %{
          "old_name" => existing_name,
          "name" => "NEW_NAME",
          "value" => "",
          "md5" => existing_var_md5
        },
        %{"old_name" => "", "name" => "EV2", "value" => random_value, "md5" => ""}
      ]

      [%ConfigFile{path: existing_path, md5: existing_file_md5, content: existing_content} | _] =
        secret.files

      random_content = random_content()

      file_params = [
        %{
          "old_path" => existing_path,
          "path" => "/home/new_path",
          "content" => "",
          "md5" => existing_file_md5
        },
        %{"old_path" => "", "path" => "/home/path2", "content" => random_content, "md5" => ""}
      ]

      assert %{
               env_vars: [
                 %EnvironmentVariable{name: "NEW_NAME", value: ^existing_value},
                 %EnvironmentVariable{name: "EV2", value: ^random_value}
               ],
               files: [
                 %ConfigFile{path: "/home/new_path", content: ^existing_content},
                 %ConfigFile{path: "/home/path2", content: ^random_content}
               ]
             } = SecretUpdater.consolidate(secret, env_var_params, file_params)
    end
  end

  describe "do_consolidate/3 for env vars" do
    test "when variable is updated then old value is preserved", %{secret: secret} do
      [
        %EnvironmentVariable{name: old_name, md5: existing_md5, value: existing_value}
        | rest_of_vars
      ] = secret.env_vars

      consolidated_rest_of_vars = Enum.map(rest_of_vars, &%{&1 | md5: nil})
      new_name = "NEW_NAME"

      new_vars = [
        %{"old_name" => old_name, "name" => new_name, "value" => "", "md5" => existing_md5}
        | Enum.map(rest_of_vars, &to_params/1)
      ]

      assert [
               %EnvironmentVariable{name: ^new_name, value: ^existing_value}
               | ^consolidated_rest_of_vars
             ] = SecretUpdater.do_consolidate(secret.env_vars, new_vars, :env_var)
    end

    test "when variable's value is updated then new value is preserved", %{secret: secret} do
      [%EnvironmentVariable{name: existing_name, md5: existing_md5} | rest_of_vars] =
        secret.env_vars

      consolidated_rest_of_vars = Enum.map(rest_of_vars, &%{&1 | md5: nil})
      value = random_value()

      new_vars = [
        %{
          "old_name" => existing_name,
          "name" => existing_name,
          "value" => value,
          "md5" => existing_md5
        }
        | Enum.map(rest_of_vars, &to_params/1)
      ]

      assert [
               %EnvironmentVariable{name: ^existing_name, value: ^value}
               | ^consolidated_rest_of_vars
             ] = SecretUpdater.do_consolidate(secret.env_vars, new_vars, :env_var)
    end

    test "when variable's name and value are updated then old var is vanished", %{secret: secret} do
      [%EnvironmentVariable{name: old_name, md5: existing_md5} | rest_of_vars] = secret.env_vars

      new_name = "NEW_NAME"
      value = random_value()

      new_vars = [
        %{"old_name" => old_name, "name" => new_name, "value" => value, "md5" => existing_md5}
        | Enum.map(rest_of_vars, &to_params/1)
      ]

      assert consolidated_vars = SecretUpdater.do_consolidate(secret.env_vars, new_vars, :env_var)

      assert ^consolidated_vars = [
               %EnvironmentVariable{name: new_name, value: value}
               | Enum.map(rest_of_vars, &%{&1 | md5: nil})
             ]
    end

    test "when new var is provided then other vars are preserved", %{secret: secret} do
      new_name = "NEW_NAME"
      value = random_value()

      new_vars = [
        %{"old_name" => "", "name" => new_name, "value" => value}
        | Enum.map(secret.env_vars, &to_params/1)
      ]

      assert consolidated_vars = SecretUpdater.do_consolidate(secret.env_vars, new_vars, :env_var)

      assert ^consolidated_vars =
               Enum.map(secret.env_vars, &%{&1 | md5: nil}) ++
                 [%EnvironmentVariable{name: new_name, value: value}]
    end

    test "when new var is provided with empty value then other vars are preserved",
         %{secret: secret} do
      new_name = "NEW_NAME"
      value = ""

      new_vars = [
        %{"old_name" => "", "name" => new_name, "value" => value}
        | Enum.map(secret.env_vars, &to_params/1)
      ]

      assert consolidated_vars = SecretUpdater.do_consolidate(secret.env_vars, new_vars, :env_var)
      assert ^consolidated_vars = Enum.map(secret.env_vars, &%{&1 | md5: nil})
    end

    test "when new var is provided with undefined value then other vars are preserved",
         %{secret: secret} do
      new_name = "NEW_NAME"
      value = "undefined"

      new_vars = [
        %{"old_name" => "", "name" => new_name, "value" => value}
        | Enum.map(secret.env_vars, &to_params/1)
      ]

      assert consolidated_vars = SecretUpdater.do_consolidate(secret.env_vars, new_vars, :env_var)
      assert ^consolidated_vars = Enum.map(secret.env_vars, &%{&1 | md5: nil})
    end

    test "when var is removed then old var is vanished", %{secret: secret} do
      [%EnvironmentVariable{} | rest_of_vars] = secret.env_vars
      new_vars = Enum.map(rest_of_vars, &to_params/1)
      consolidated_rest_of_vars = Enum.map(rest_of_vars, &%{&1 | md5: nil})

      assert ^consolidated_rest_of_vars =
               SecretUpdater.do_consolidate(secret.env_vars, new_vars, :env_var)
    end
  end

  describe "do_consolidate/3 for files" do
    test "when filename is updated then old file content is preserved", %{secret: secret} do
      [%ConfigFile{path: old_path, md5: existing_md5, content: existing_content} | rest_of_files] =
        secret.files

      consolidated_rest_of_files = Enum.map(rest_of_files, &%{&1 | md5: nil})
      new_path = "/home/new_path"

      new_files = [
        %{"old_path" => old_path, "path" => new_path, "content" => "", "md5" => existing_md5}
        | Enum.map(rest_of_files, &to_params/1)
      ]

      assert [
               %ConfigFile{path: ^new_path, content: ^existing_content}
               | ^consolidated_rest_of_files
             ] = SecretUpdater.do_consolidate(secret.files, new_files, :file)
    end

    test "when content is updated then new file content is preserved", %{secret: secret} do
      [%ConfigFile{path: existing_path, md5: existing_md5} | rest_of_files] = secret.files
      consolidated_rest_of_files = Enum.map(rest_of_files, &%{&1 | md5: nil})
      content = random_content()

      new_files = [
        %{
          "old_path" => existing_path,
          "path" => existing_path,
          "content" => content,
          "md5" => existing_md5
        }
        | Enum.map(rest_of_files, &to_params/1)
      ]

      assert [%ConfigFile{path: ^existing_path, content: ^content} | ^consolidated_rest_of_files] =
               SecretUpdater.do_consolidate(secret.files, new_files, :file)
    end

    test "when filename and content is updated then old file is vanished", %{secret: secret} do
      [%ConfigFile{path: old_path, md5: existing_md5} | rest_of_files] = secret.files

      new_path = "/home/new_path"
      content = random_content()

      new_files = [
        %{"old_path" => old_path, "path" => new_path, "content" => content, "md5" => existing_md5}
        | Enum.map(rest_of_files, &to_params/1)
      ]

      assert consolidated_files = SecretUpdater.do_consolidate(secret.files, new_files, :file)

      assert ^consolidated_files = [
               %ConfigFile{path: new_path, content: content}
               | Enum.map(rest_of_files, &%{&1 | md5: nil})
             ]
    end

    test "when new file is provided then other files are preserved", %{secret: secret} do
      new_path = "/home/new_path"
      content = random_content()

      new_files = [
        %{"old_path" => "", "path" => new_path, "content" => content}
        | Enum.map(secret.files, &to_params/1)
      ]

      assert consolidated_files = SecretUpdater.do_consolidate(secret.files, new_files, :file)

      assert ^consolidated_files =
               Enum.map(secret.files, &%{&1 | md5: nil}) ++
                 [%ConfigFile{path: new_path, content: content}]
    end

    test "when new file is provided with empty content then other files are preserved",
         %{secret: secret} do
      new_path = "/home/new_path"
      content = ""

      new_files = [
        %{"old_path" => "", "path" => new_path, "content" => content}
        | Enum.map(secret.files, &to_params/1)
      ]

      assert consolidated_files = SecretUpdater.do_consolidate(secret.files, new_files, :file)
      assert ^consolidated_files = Enum.map(secret.files, &%{&1 | md5: nil})
    end

    test "when new file is provided with undefined content then other files are preserved",
         %{secret: secret} do
      new_path = "/home/new_path"
      content = "undefined"

      new_files = [
        %{"old_path" => "", "path" => new_path, "content" => content}
        | Enum.map(secret.files, &to_params/1)
      ]

      assert consolidated_files = SecretUpdater.do_consolidate(secret.files, new_files, :file)
      assert ^consolidated_files = Enum.map(secret.files, &%{&1 | md5: nil})
    end

    test "when file is removed then old file is vanished", %{secret: secret} do
      [%ConfigFile{} | rest_of_files] = secret.files
      new_files = Enum.map(rest_of_files, &to_params/1)
      consolidated_rest_of_files = Enum.map(rest_of_files, &%{&1 | md5: nil})

      assert ^consolidated_rest_of_files =
               SecretUpdater.do_consolidate(secret.files, new_files, :file)
    end
  end

  defp to_params(data),
    do:
      data
      |> Map.from_struct()
      |> put_old_key()
      |> Map.new(&{to_string(elem(&1, 0)), elem(&1, 1)})

  defp put_old_key(data = %{name: name}), do: Map.put(data, :old_name, name)
  defp put_old_key(data = %{path: path}), do: Map.put(data, :old_path, path)

  defp env_var(args), do: struct!(Front.Models.EnvironmentVariable, args)
  defp cfg_file(args), do: struct!(Front.Models.ConfigFile, args)
  defp random_md5, do: :crypto.hash(:md5, :crypto.strong_rand_bytes(64))
  defp random_value, do: :crypto.strong_rand_bytes(32) |> Base.encode64()
  defp random_content, do: :crypto.strong_rand_bytes(128) |> Base.encode64()
end
