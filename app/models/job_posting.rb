class JobPosting < ApplicationRecord
  # Validations
  validates :company, presence: true
  validates :title, presence: true
  validates :description, presence: true
  validates :url, presence: true, uniqueness: true, format: {
    with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
    message: 'must be a valid HTTP or HTTPS URL'
  }

  # Status enum - string-backed for SQLite compatibility
  enum :status, { suggested: 'suggested', applied: 'applied', ignored: 'ignored', exported: 'exported' }

  # Associations
  has_many :job_skill_assessments, dependent: :destroy
  has_many :applications, dependent: :nullify

  # Scopes
  scope :remote, -> { where(remote: true) }
  scope :recent, -> { order(posted_at: :desc) }
  scope :by_score, -> { order(score: :desc, updated_at: :desc) }
  scope :by_company, ->(company) { where(company: company) }
  scope :by_source, ->(source) { where(source: source) }
  scope :suggested_only, -> { where(status: 'suggested') }
  scope :active_board, -> { suggested_only }
  scope :board_visible, -> { suggested_only } # Defense in depth - same as active_board for now

  # Search scope (simple LIKE for SQLite compatibility)
  scope :search, lambda { |query|
    return all if query.blank?

    sanitized = sanitize_sql_like(query)
    where('company LIKE ? OR title LIKE ? OR description LIKE ?',
          "%#{sanitized}%", "%#{sanitized}%", "%#{sanitized}%")
  }

  # Filter scopes
  scope :posted_since, ->(days) { where(posted_at: days.to_i.days.ago..) }
  scope :min_score, ->(score) { where(score: score.to_i..) }

  # Status management methods
  def mark_applied!
    update!(status: 'applied', applied_at: Time.current)
  end

  def mark_exported!
    update!(status: 'exported', exported_at: Time.current)
  end

  def mark_ignored!(reason: nil)
    notes_text = reason ? "Ignored: #{reason}" : nil
    update!(status: 'ignored', ignored_at: Time.current, notes: notes_text)
  end

  # Return a summary of the job
  def summary
    description&.truncate(200)
  end

  # Check if job is remote
  def remote?
    remote == true
  end

  # Check if PDFs were generated today
  def generated_today?
    exported_at&.today? || false
  end

  # Get the most recent application for this job
  def latest_application
    applications.recent.first
  end

  # Check if any PDFs exist for this job
  def has_pdfs?
    applications.exists?(status: :generated)
  end
end
