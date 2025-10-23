module JobWizard
  class EffectiveSkillsService
    PROFICIENCY_THRESHOLD = ENV.fetch('JW_PROF_THRESHOLD', 3).to_i

    def initialize(job_posting)
      @job_posting = job_posting
    end

    def effective_skills
      verified_skills = load_verified_skills
      overrides = load_job_overrides

      # Start with verified skills from YAML
      effective = Set.new(verified_skills)

      # Add job-specific "have" skills above threshold
      overrides[:have].each do |skill, proficiency|
        effective.add(skill) if proficiency && proficiency >= PROFICIENCY_THRESHOLD
      end

      # Remove job-specific "don't have" skills
      overrides[:dont_have].each do |skill|
        effective.delete(skill)
      end

      effective.to_a.sort
    end

    def skill_summary
      verified_skills = load_verified_skills
      overrides = load_job_overrides

      {
        verified_count: verified_skills.size,
        included_count: overrides[:have].count { |_, prof| prof && prof >= PROFICIENCY_THRESHOLD },
        excluded_count: overrides[:dont_have].size,
        total_effective: effective_skills.size
      }
    end

    private

    def load_verified_skills
      experience_data = YAML.safe_load_file(Rails.root.join('config/job_wizard/experience.yml'))
      skills = experience_data['skills'] || []
      skills.map { |skill| skill['name'].downcase.strip }
    rescue StandardError => e
      Rails.logger.warn "Failed to load verified skills: #{e.message}"
      []
    end

    def load_job_overrides
      assessments = @job_posting.job_skill_assessments

      have_skills = {}
      dont_have_skills = Set.new

      assessments.each do |assessment|
        if assessment.have?
          have_skills[assessment.skill_name] = assessment.proficiency
        else
          dont_have_skills.add(assessment.skill_name)
        end
      end

      {
        have: have_skills,
        dont_have: dont_have_skills.to_a
      }
    end
  end
end
