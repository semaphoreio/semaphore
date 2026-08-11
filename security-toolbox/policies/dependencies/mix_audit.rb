# rubocop:disable all

class Policy::MixAudit < Policy
  def initialize(args)
    super(args)
    @ignore_packages = args[:ignore_packages] || nil
    @ignore_file = args[:ignore_file] || nil
  end

  def test
    return false unless synchronize_advisory_db

    command = [
      "~/.mix/escripts/mix_audit"
    ]

    if @ignore_packages != nil
      command << "--ignore-package-names #{@ignore_packages}"
    end

    if @ignore_file != nil
      command << "--ignore-file #{@ignore_file}"
    end

    @output = `#{command.join(" ")}`
    $?.success?
  end

  def reason
    @output
  end

  def synchronize_advisory_db
    db_path = File.join(Dir.home, ".local", "share", "elixir-security-advisories-mirego")

    if File.directory?(db_path)
      synced = system("git", "-C", db_path, "pull", "--rebase", "--quiet", "origin", "main")
    else
      synced = system("git", "clone", "--quiet", "https://github.com/mirego/elixir-security-advisories.git", db_path)
    end

    advisory_count = Dir.glob(File.join(db_path, "packages", "**", "*.yml")).length

    if !synced || advisory_count == 0
      @output = "Could not synchronize the advisory database at #{db_path} (synced=#{!!synced}, advisories=#{advisory_count}). Without it, mix_audit reports 'No vulnerabilities found' from an empty database."
      return false
    end

    true
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
        name: "~/.mix/escripts/mix_audit",
        install: Proc.new do
          command = [
            "mix local.hex --force",
            "mix local.rebar --force",
            "mix escript.install hex mix_audit --force"
          ]

          `#{command.join(" && ")}`
          $?.exitstatus
        end
      }
    ]
  end
end
