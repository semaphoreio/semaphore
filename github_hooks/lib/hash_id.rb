module HashId

  def generate_hash_id
    self.hash_id = SecureRandom.uuid
  end

  def self.included(base)
    base.validates :hash_id, :presence => true, :uniqueness => true, :on => :create
    base.before_validation :generate_hash_id, :on => :create
  end

end
