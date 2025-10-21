class Application < ApplicationRecord
  belongs_to :job_posting, optional: true

  # Enums
  enum :status, { draft: 0, generated: 1, error: 2 }, default: :draft

  # Validations
  validates :company, presence: true
  validates :role, presence: true
  validates :job_description, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_company, ->(company) { where(company: company) }

  # Check if PDFs are ready
  def pdfs_ready?
    generated? && output_path.present?
  end

  # Get flags by category
  def warnings
    flags&.dig('warnings') || []
  end

  def blocking_flags
    flags&.dig('blocking') || []
  end

  def info_flags
    flags&.dig('info') || []
  end

  def unverified_skills
    flags&.dig('unverified_skills') || []
  end
end
