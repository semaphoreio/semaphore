# rubocop:disable all

class Policy::TrivyTableOutput < Policy
  def initialize(args)
    super(args)

    @scanners = args[:scanners]
  end

  def test
    command = [
      "trivy",
      "convert",
      "--format table",
      "--output table.txt",
      "--scanners #{@scanners}",
      "out/docker-scan-trivy.json"
    ]

    @output = `#{command.join(" ")} && cat table.txt && rm table.txt`
    $?.success?
  end

  def printable?
    true
  end

  def reason
    @output
  end

  def dependencies
    [
      {
        name: "trivy",
        install: Proc.new do
          `curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin`
          $?.exitstatus
        end
      }
    ]
  end
end
