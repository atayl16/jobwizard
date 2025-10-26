# frozen_string_literal: true

module JobWizard
  module Writers
    # Template-based cover letter writer (no AI)
    class TemplatesWriter < Writer
      def self.cover_letter(profile:, experience:, jd_text:, company:, role:, allowed_skills:)
        new(profile, experience, jd_text, company, role, allowed_skills).generate
      end

      def initialize(profile, experience, jd_text, company, role, allowed_skills)
        @profile = profile
        @experience = experience
        @jd_text = jd_text
        @company = company
        @role = role
        @allowed_skills = allowed_skills
      end

      def generate
        [
          header,
          greeting,
          opening_paragraph,
          core_paragraph,
          optional_bullets,
          closing_paragraph
        ].compact.join("\n\n")
      end

      private

      def header
        "#{Date.current.strftime('%B %d, %Y')}\n\n"
      end

      def greeting
        "Dear #{company_hiring_team},\n\n"
      end

      def company_hiring_team
        # Try to extract hiring team name from JD, fallback to generic
        if @jd_text.match?(/hiring manager|hiring team|recruiter/i)
          "#{@company} Hiring Team"
        else
          'Hiring Manager'
        end
      end

      def opening_paragraph
        "I am writing to express my strong interest in the #{@role} position at #{@company}. " \
          "With my background in #{primary_skills_text} and experience building #{experience_summary}, " \
          'I am excited about the opportunity to contribute to your team.'
      end

      def primary_skills_text
        expert_skills = @experience.skills_by_level[:expert].first(3)
        if expert_skills.any?
          expert_skills.pluck(:name).join(', ')
        else
          'full-stack development'
        end
      end

      def experience_summary
        recent_position = @experience.positions&.first
        if recent_position
          (recent_position['description']&.downcase || 'scalable applications').to_s
        else
          'scalable applications'
        end
      end

      def core_paragraph
        achievements = select_relevant_achievements
        if achievements.any?
          "In my most recent role at #{recent_company}, I #{achievements.first.downcase}. " \
            "This experience aligns well with #{@company}'s needs for #{role_keywords}."
        else
          "My experience with #{primary_skills_text} makes me well-suited for this role, " \
            "particularly in areas requiring #{role_keywords}."
        end
      end

      def select_relevant_achievements
        recent_position = @experience.positions&.first
        return [] unless recent_position&.dig('achievements')

        # Filter achievements that mention allowed skills
        achievements = recent_position['achievements']
        if @allowed_skills.present?
          achievements.select do |achievement|
            @allowed_skills.any? { |skill| achievement.downcase.include?(skill.downcase) }
          end
        else
          achievements
        end.first(2)
      end

      def recent_company
        @experience.positions&.first&.dig('company') || 'my previous company'
      end

      def role_keywords
        # Extract key terms from role title
        keywords = @role.downcase.split(/\s+/).reject { |w| %w[senior lead staff principal].include?(w) }
        keywords.any? ? keywords.join(' and ') : 'technical expertise'
      end

      def optional_bullets
        achievements = select_relevant_achievements
        return nil if achievements.empty? || achievements.length == 1

        bullets = achievements[1..2].map { |achievement| "• #{achievement}" }
        bullets.join("\n")
      end

      def closing_paragraph
        "I am excited about the opportunity to bring my #{primary_skills_text} expertise to #{@company} " \
          "and would welcome the chance to discuss how my background aligns with your team's goals. " \
          "Thank you for considering my application.\n\n" \
          "Best regards,\n" \
          "#{@profile['name']}"
      end
    end
  end
end

