defmodule Front.Models.Forkable do
  @repositories [
    %{
      title: "Android (Kotlin)",
      icon: %{
        name: "lang-android.svg",
        class: "fr nt1",
        width: "32"
      },
      description:
        "Build the app, run lint and unit tests, use the promotion to run integration tests.",
      urls: %{
        github: "https://github.com/semaphoreci-demos/semaphore-demo-android",
        bitbucket: "https://bitbucket.org/semaphore-demos/semaphore-demo-android"
      },
      name: "android",
      project_name: "semaphore-demo-android"
    },
    %{
      title: "Elixir (Phoenix)",
      icon: %{
        name: "lang-elixir.svg",
        class: "fr nt1",
        width: "32"
      },
      description:
        "Compile and build the app, run code through credo and formatter, and run tests.",
      urls: %{
        github: "https://github.com/semaphoreci-demos/semaphore-demo-elixir-phoenix",
        bitbucket: "https://bitbucket.org/semaphore-demos/semaphore-demo-elixir-phoenix"
      },
      name: "elixir-phoenix",
      project_name: "semaphore-demo-elixir-phoenix"
    },
    %{
      title: "Go",
      icon: %{
        name: "lang-go.svg",
        class: "fr nt2",
        width: "42"
      },
      description: "Go get and build, check code style, and run basic and web server tests.",
      urls: %{
        github: "https://github.com/semaphoreci-demos/semaphore-demo-go",
        bitbucket: "https://bitbucket.org/semaphore-demos/semaphore-demo-go"
      },
      name: "go",
      project_name: "semaphore-demo-go"
    },
    %{
      title: "Ruby (Rails)",
      icon: %{
        name: "lang-ruby.svg",
        class: "fr nt1",
        width: "24"
      },
      description:
        "Bundle, run style and security audit and finish with unit and integration tests.",
      urls: %{
        github: "https://github.com/semaphoreci-demos/semaphore-demo-ruby-rails",
        bitbucket: "https://bitbucket.org/semaphore-demos/semaphore-demo-ruby-rails"
      },
      name: "ruby-rails",
      project_name: "semaphore-demo-ruby-rails"
    },
    %{
      title: "JavaScript",
      icon: %{
        name: "lang-javascript.svg",
        class: "fr nt1",
        width: "24"
      },
      description: "Install dependencies and run lint and unit tests followed by e2e tests.",
      urls: %{
        github: "https://github.com/semaphoreci-demos/semaphore-demo-javascript",
        bitbucket: "https://bitbucket.org/semaphore-demos/semaphore-demo-javascript"
      },
      name: "javascript",
      project_name: "semaphore-demo-javascript"
    },
    %{
      title: "Java (Spring)",
      icon: %{
        name: "lang-spring.svg",
        class: "fr nt1",
        width: "24"
      },
      description: "Build, run unit and integration tests followed by performance tests.",
      urls: %{
        github: "https://github.com/semaphoreci-demos/semaphore-demo-java-spring",
        bitbucket: "https://bitbucket.org/semaphore-demos/semaphore-demo-java-spring"
      },
      name: "java-spring",
      project_name: "semaphore-demo-java-spring"
    },
    %{
      title: "Python (Django)",
      icon: %{
        name: "lang-django.svg",
        class: "fr nt1",
        width: "24"
      },
      description:
        "Install dependencies, analyze code, run the unit, browser, and security tests.",
      urls: %{
        github: "https://github.com/semaphoreci-demos/semaphore-demo-python-django",
        bitbucket: "https://bitbucket.org/semaphore-demos/semaphore-demo-python-django"
      },
      name: "python-django",
      project_name: "semaphore-demo-python-django"
    },
    %{
      title: "Scala (Play)",
      icon: %{
        name: "lang-play.svg",
        class: "fr nt1",
        width: "24"
      },
      description: "Run the Scala Play project with two different Java versions in parallel.",
      urls: %{
        github: "https://github.com/semaphoreci-demos/semaphore-demo-scala-play",
        bitbucket: "https://bitbucket.org/semaphore-demos/semaphore-demo-scala-play"
      },
      name: "scala-play",
      project_name: "semaphore-demo-scala-play"
    },
    %{
      title: "Flutter",
      icon: %{
        name: "lang-flutter.svg",
        class: "fr nt1",
        width: "24"
      },
      description: "Get dependencies, analyze code, and run unit tests for iOS and Android.",
      urls: %{
        github: "https://github.com/semaphoreci-demos/semaphore-demo-flutter",
        bitbucket: "https://bitbucket.org/semaphore-demos/semaphore-demo-flutter"
      },
      name: "flutter",
      project_name: "semaphore-demo-flutter"
    },
    %{
      title: "PHP (Laravel)",
      icon: %{
        name: "lang-laravel.svg",
        class: "fr nt1",
        width: "24"
      },
      description:
        "Install dependencies, analyze code, run the unit, browser, and security tests.",
      urls: %{
        github: "https://github.com/semaphoreci-demos/semaphore-demo-php-laravel",
        bitbucket: "https://bitbucket.org/semaphore-demos/semaphore-demo-php-laravel"
      },
      name: "php-laravel",
      project_name: "semaphore-demo-php-laravel"
    },
    %{
      title: "React Native",
      icon: %{
        name: "lang-react-native.svg",
        class: "fr nt1",
        width: "32"
      },
      description: "Install dependencies, run unit, and integration tests for Android and iOS.",
      urls: %{
        github: "https://github.com/semaphoreci-demos/semaphore-demo-react-native",
        bitbucket: "https://bitbucket.org/semaphore-demos/semaphore-demo-react-native"
      },
      name: "react-native",
      project_name: "semaphore-demo-react-native"
    },
    %{
      title: "iOS Xcode",
      icon: %{
        name: "lang-xcode.svg",
        class: "fr nt1",
        width: "32"
      },
      description: "Run tests, use Fastlane to build the app, and create screenshots.",
      urls: %{
        github: "https://github.com/semaphoreci-demos/semaphore-demo-ios-swift-xcode",
        bitbucket: "https://bitbucket.org/semaphore-demos/semaphore-demo-ios-swift-xcode"
      },
      name: "ios-swift-xcode",
      project_name: "semaphore-demo-ios-swift-xcode"
    },
    %{
      title: "Monorepo",
      icon: %{
        name: "lang-monorepo.svg",
        class: "fr nt1",
        width: "32"
      },
      description: "Use change_in to run jobs only on updated services.",
      urls: %{
        github: "https://github.com/semaphoreci-demos/semaphore-demo-monorepo",
        bitbucket: "https://bitbucket.org/semaphore-demos/semaphore-demo-monorepo"
      },
      name: "monorepo",
      project_name: "semaphore-demo-monorepo"
    }
  ]

  def all do
    @repositories
  end

  def find(name) do
    @repositories |> Enum.find(fn repo -> repo.name == name end)
  end

  def map_integration_types(integration_types) when is_list(integration_types) do
    integration_types
    |> Enum.map(fn type -> map_integration_types(type) end)
    |> Enum.uniq()
  end

  def map_integration_types(:GITHUB_APP), do: "github"
  def map_integration_types(:GITHUB_OAUTH_TOKEN), do: "github"
  def map_integration_types(:BITBUCKET), do: "bitbucket"

  def map_integration_types(integration_type) do
    integration_type
    |> InternalApi.RepositoryIntegrator.IntegrationType.key()
    |> map_integration_types()
  end

  def map_repository_provider("bitbucket"), do: "bitbucket"
  def map_repository_provider("github"), do: "github_oauth_token"

  def repository_url(repository, provider) do
    repository.urls[String.to_atom(provider)]
  end

  def supported_by_user?(user, "github"),
    do: supported_by_user?(user.github_scope)

  def supported_by_user?(user, "bitbucket"),
    do: supported_by_user?(user.bitbucket_scope)

  def supported_by_user?(user_scope),
    do: Enum.member?([:PUBLIC, :PRIVATE], user_scope)
end
