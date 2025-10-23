# frozen_string_literal: true

module JobWizard
  # Provides role summary and skill matching for job postings
  class JobRoleAnalyzer
    attr_reader :job_posting, :experience_loader

    def initialize(job_posting)
      @job_posting = job_posting
      @experience_loader = ExperienceLoader.new
    end

    # Generate a 3-5 bullet summary of the role
    def role_summary
      bullets = []
      
      # Extract key responsibilities
      responsibilities = extract_responsibilities
      bullets.concat(responsibilities.first(3))
      
      # Extract must-have skills
      must_have_skills = extract_must_have_skills
      bullets.concat(must_have_skills.first(2))
      
      bullets.uniq.first(5)
    end

    # Calculate alignment score (0-100) based on verified skills
    def alignment_score
      jd_skills = extract_jd_skills
      verified_skills = experience_loader.all_skill_names
      
      return 0 if jd_skills.empty?
      
      matched = jd_skills.count { |skill| verified_skills.include?(skill) }
      (matched.to_f / jd_skills.length * 100).round
    end

    # Suggest what to highlight based on experience
    def highlight_suggestions
      suggestions = []
      jd_text = job_posting.description.downcase
      
      # Check for Rails matches
      if jd_text.include?('rails') || jd_text.include?('ruby')
        suggestions << 'Rails/Ruby experience'
      end
      
      # Check for React/frontend
      if jd_text.include?('react') || jd_text.include?('javascript')
        suggestions << 'Frontend/React skills'
      end
      
      # Check for backend
      if jd_text.include?('api') || jd_text.include?('backend')
        suggestions << 'API/Backend experience'
      end
      
      suggestions
    end

    # Categorize skills into Verified/Unverified/Not applicable
    def skill_categories
      jd_skills = extract_jd_skills
      verified_skills = experience_loader.all_skill_names
      not_claimed = experience_loader.not_claimed_skills.map(&:downcase)
      
      {
        verified: jd_skills.select { |s| verified_skills.include?(s) },
        unverified: jd_skills.reject { |s| verified_skills.include?(s) || not_claimed.include?(s) },
        not_applicable: not_claimed.select { |s| jd_skills.include?(s) }
      }
    end

    private

    def extract_responsibilities
      text = job_posting.description
      lines = text.split("\n").map(&:strip).reject(&:blank?)
      
      # Look for responsibility indicators
      bullets = []
      lines.each do |line|
        if line.match?(/^\s*[-•*]\s+/i) || line.downcase.match?(/responsibilit|will|must|should/)
          bullets << sanitize_line(line)
        end
      end
      
      # Fallback: extract any line with action verbs
      if bullets.empty?
        lines.each do |line|
          if line.match?(/^\s*(build|develop|create|design|implement|maintain|collaborate)/i)
            bullets << sanitize_line(line)
          end
        end
      end
      
      bullets.first(5)
    end

    def extract_must_have_skills
      text = job_posting.description.downcase
      skills = []
      
      # Look for "must have", "required", "experience with"
      if text.match?(/must have|required|experience with/i)
        common_skills = %w[ruby rails javascript react python java sql postgresql mysql redis docker kubernetes aws azure git github]
        common_skills.each do |skill|
          if text.include?(skill)
            skills << skill.titleize
          end
        end
      end
      
      skills
    end

    def extract_jd_skills
      text = job_posting.description.downcase
      common_skills = %w[ruby rails javascript react python java sql postgresql mysql redis docker kubernetes aws azure git github typescript nodejs vue angular]
      
      common_skills.select { |skill| text.include?(skill) }.map(&:titleize)
    end

    def sanitize_line(line)
      # Remove HTML tags and entities
      line.gsub(/<[^>]+>/, '')
          .gsub(/&nbsp;/, ' ')
          .gsub(/&[a-z]+;/, '')
          .strip
    end
  end
end

