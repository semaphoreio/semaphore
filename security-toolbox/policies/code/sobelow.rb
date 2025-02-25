# rubocop:disable all

class Policy::Sobelow < Policy
  def initialize(args)
    super(args)
    @severity = args[:severity] || "medium"
    @ignores = args[:ignores] || nil
  end

  def test
    command = [
      "~/.mix/escripts/sobelow",
      "--exit #{@severity}",
      "--threshold #{@severity}",
      "--skip",
      "--config"
    ]

    if @ignores != nil
      command << "-i #{@ignores}"
    end

    @output = `#{command.join(" ")}`
    $?.success?
  end

  def reason
    @output
  end

  def dependencies
    [
      {
        name: "erl",
        install: Proc.new do
          `sudo apt-get update && sudo apt-get -y install erlang`
          $?.exitstatus
        end
      },
      {
        name: "elixir",
        install: Proc.new do
          `sudo apt-get update && sudo apt-get -y install elixir`
          $?.exitstatus
        end
      },
      {
        name: "~/.mix/escripts/sobelow",
        install: Proc.new do
          command = [
            "mix local.hex --force",
            "mix local.rebar --force",
            "mix escript.install hex sobelow --force"
          ]

          `#{command.join(" && ")}`
          $?.exitstatus
        end
      }
    ]
  end
end
