class Gravatar
  def self.avatar_url(author_email, options = {})
    gravatar_id = Digest::MD5.hexdigest(author_email.downcase) unless author_email.nil?
    size = options[:size].present? ? options[:size] : "48"
    "https://gravatar.com/avatar/#{gravatar_id}.png?d=mm&s=#{size}"
  end
end
