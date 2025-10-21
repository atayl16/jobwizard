class JobPosting < ApplicationRecord
  # Validations
  validates :company, presence: true
  validates :title, presence: true
  validates :description, presence: true
  validates :url, presence: true, uniqueness: true

  # Scopes
  scope :remote, -> { where(remote: true) }
  scope :recent, -> { order(posted_at: :desc) }
  scope :by_score, -> { order(score: :desc, updated_at: :desc) }
  scope :by_company, ->(company) { where(company: company) }
  scope :by_source, ->(source) { where(source: source) }

  # Return a summary of the job
  def summary
    description&.truncate(200)
  end

  # Check if job is remote
  def remote?
    remote == true
  end
end
