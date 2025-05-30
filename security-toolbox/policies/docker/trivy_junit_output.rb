# rubocop:disable all

class Policy::TrivyJunitOutput < Policy
  def initialize(args)
    super(args)

    @template_path = File.join(File.dirname(__FILE__), "trivyfs/junit.tpl")
  end

  def test
    command = [
      "trivy",
      "convert",
      "--format template",
      "--template '@#{@template_path}'",
      "--output out/docker-scan-junit.xml",
      "out/results.json"
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
        name: "trivy",
        install: Proc.new do
          `curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin`
          $?.exitstatus
        end
      }
    ]
  end
end
