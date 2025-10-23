# frozen_string_literal: true

class AiUsage < ApplicationRecord
  # Validations
  validates :model, presence: true
  validates :feature, presence: true
  validates :prompt_tokens, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :completion_tokens, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :month_to_date, -> { where(created_at: Time.current.beginning_of_month..Time.current) }
  scope :by_feature, ->(feature) { where(feature: feature) }
  scope :recent, -> { order(created_at: :desc) }

  # Format cost as dollars
  def cost_dollars
    cost_cents / 100.0
  end

  # Total tokens used
  def total_tokens
    prompt_tokens + completion_tokens + cached_input_tokens
  end
end
