class Policy::TrivyFs < Policy
  def initialize(args)
    super(args)
    @severity = args[:severity] || "HIGH,CRITICAL"
    @template_path = File.join(File.dirname(__FILE__), "trivyfs/junit.tpl")
    @ignore_policy = args[:ignore_policy] || nil
  end

  def test
    command = [
      "trivy",
      "fs",
      "--exit-code 1",
      "--severity #{@severity}",
      "--ignore-unfixed",
      "--format template",
      "--scanners vuln,license",
      "--template '@#{@template_path}'",
      "-o results.xml"
    ]

    if @ignore_policy != nil
      command << "--ignore-policy #{@ignore_policy}"
    end

    command << "."

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
