class JobSkillAssessment < ApplicationRecord
  belongs_to :job_posting

  validates :skill_name, presence: true
  validates :proficiency, inclusion: { in: 1..5 }, if: -> { have? && proficiency.present? }
  validates :proficiency, absence: true, unless: :have?
  validates :skill_name, uniqueness: { scope: :job_posting_id }

  before_save :normalize_skill_name

  private

  def normalize_skill_name
    self.skill_name = skill_name.downcase.strip
  end
end
