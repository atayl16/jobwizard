class JobSource < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :provider, presence: true, inclusion: { in: %w[greenhouse lever] }
  validates :slug, presence: true, uniqueness: { scope: :provider }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_provider, ->(provider) { where(provider: provider) }

  # Update last fetched timestamp
  def mark_as_fetched!
    update(last_fetched_at: Time.current)
  end

  # Check if needs refresh (older than 24 hours)
  def needs_refresh?
    last_fetched_at.nil? || last_fetched_at < 24.hours.ago
  end
end
