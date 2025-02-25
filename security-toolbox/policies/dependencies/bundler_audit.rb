# rubocop:disable all

class Policy::BundlerAudit < Policy
  def initialize(args)
    super(args)
  end

  def test
    command = [
      "bundle-audit",
      "check",
      "--update"
    ]

    @output = `#{command.join(" ")}`
    $?.success?
  end

  def reason
    @output
  end

  def dependencies
    [
      {
        name: "bundle-audit",
        install: Proc.new do
          command = [
            "gem install bundler-audit --no-doc"
          ]

          `#{command.join(" && ")}`
          $?.exitstatus
        end
      }
    ]
  end
end
