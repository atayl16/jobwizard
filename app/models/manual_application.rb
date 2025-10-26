# frozen_string_literal: true

class ManualApplication < ApplicationRecord
  # Validations
  validates :company, presence: true
  validates :position, presence: true
  validates :applied_at, presence: true

  # Status enum
  enum :status, {
    submitted: 'submitted',
    under_review: 'under_review',
    rejected: 'rejected',
    accepted: 'accepted',
    offer: 'offer'
  }

  # Scopes
  scope :recent, -> { order(applied_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_company, ->(company) { where(company: company) }

  # Get a summary of the application
  def summary
    "#{company} - #{position}"
  end
end

