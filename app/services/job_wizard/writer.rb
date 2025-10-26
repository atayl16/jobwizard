# frozen_string_literal: true

module JobWizard
  # Interface for cover letter writers (template-based or AI-powered)
  class Writer
    def self.cover_letter(profile:, experience:, jd_text:, company:, role:, allowed_skills:)
      raise NotImplementedError, 'Subclasses must implement cover_letter method'
    end
  end
end

