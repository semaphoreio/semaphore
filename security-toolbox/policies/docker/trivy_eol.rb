# rubocop:disable all

class Policy::TrivyEOL < Policy
  def initialize(args)
    super(args)
  end

  def test
    if File.exist?("out/docker-scan-trivy.json")
      require 'json'

      report = JSON.parse(File.read("out/docker-scan-trivy.json"))

      eol_detected = report.dig("Metadata", "OS", "EOSL") == true
      os_name = report.dig("Metadata", "OS", "Name") || "unknown"
      os_family = report.dig("Metadata", "OS", "Family") || "unknown"


      if eol_detected
        eol_result = {
          "Target" => "OS End of Life Check",
          "Class" => "custom",
          "Type" => "dockerfile",
          "Vulnerabilities" => [{
            "VulnerabilityID" => "OS-EOL-001",
            "Title" => "Operating System End of Life",
            "PkgName" => "#{os_family}",
            "InstalledVersion" => "#{os_name}",
            "Description" => "The operating system #{os_family} #{os_name} has reached end of life and no longer receives security updates",
            "Severity" => "HIGH",
            "References" => [
              "https://endoflife.date/#{os_family}"
            ]
          }]
        }

        report["Results"] ||= []
        report["Results"] << eol_result
      end

      File.write("out/docker-scan-trivy.json", JSON.pretty_generate(report))

      if eol_detected
        @output = "FAIL: #{os_family} #{os_name} is End of Life (EOL)"
        return false
      else
        @output = "PASS: Operating system is supported"
        return true
      end
    else
      @output = "ERROR: Failed to find docker-scan-trivy.json"
      return false
    end
  rescue => e
    @output = "ERROR: #{e.message}"
    return false
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
