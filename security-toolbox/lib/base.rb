class Base
  require "json"
  require "fileutils"
  require "time"
  require "uri"

  protected

  def severity_emoji(severity)
    {
      "CRITICAL" => "🔴",
      "HIGH" => "🟠",
      "MEDIUM" => "🟡",
      "LOW" => "🔵",
    }[severity] || "⚪"
  end

  def risk_level_emoji(level)
    {
      "CRITICAL" => "🔴",
      "HIGH" => "🟠",
      "MEDIUM" => "🟡",
      "LOW" => "🔵",
      "CLEAN" => "✅",
    }[level] || "⚪"
  end

  def severity_weight(severity)
    {
      "CRITICAL" => 0,
      "HIGH" => 1,
      "MEDIUM" => 2,
      "LOW" => 3,
    }[severity] || 4
  end

  def extract_cvss_score(vuln)
    return 0 unless vuln["cvss"]
    cvss = vuln["cvss"]
    score = cvss["v3_score"] || cvss["v2_score"] || 0
    score.to_f
  end
end
