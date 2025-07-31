# rubocop:disable all

class Policy::TrivyJunitOutput < Policy
  def initialize(args)
    super(args)

    @template_path = File.join(File.dirname(__FILE__), "trivyfs/junit.tpl")
    @output_dir = args[:output_dir] || "out"
  end

  def test
    command = [
      "trivy",
      "convert",
      "--format template",
      "--template '@#{@template_path}'",
      "--output #{@output_dir}/dependency-scan-junit.xml",
      "#{@output_dir}/dependency-scan-trivy.json"
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
