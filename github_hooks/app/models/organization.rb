class Organization < ActiveRecord::Base

  has_many :projects, :dependent => :destroy
  belongs_to :creator, :class_name => "User"

  def enforce_whitelist?
    App.enforce_whitelist || (settings&.fetch("enforce_whitelist", nil) == "true")
  end
end
