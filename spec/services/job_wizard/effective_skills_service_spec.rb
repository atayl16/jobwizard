require 'rails_helper'

RSpec.describe JobWizard::EffectiveSkillsService, type: :service do
  let(:job_posting) { JobPosting.create!(title: 'Test', company: 'Test Co', url: 'https://example.com/job', description: 'Test') }
  let(:service) { described_class.new(job_posting) }

  before do
    # Mock the YAML file to return test data
    allow(File).to receive(:exist?).and_return(true)
    allow(YAML).to receive(:safe_load_file).and_return({
                                                         'skills' => [
                                                           { 'name' => 'Ruby' },
                                                           { 'name' => 'Rails' },
                                                           { 'name' => 'JavaScript' }
                                                         ]
                                                       })
  end

  describe '#effective_skills' do
    it 'returns verified skills from YAML when no overrides' do
      expect(service.effective_skills).to contain_exactly('ruby', 'rails', 'javascript')
    end

    it 'includes job-specific skills above threshold' do
      JobSkillAssessment.create!(job_posting: job_posting, skill_name: 'React', have: true, proficiency: 4)

      expect(service.effective_skills).to include('react')
    end

    it 'excludes job-specific skills below threshold' do
      JobSkillAssessment.create!(job_posting: job_posting, skill_name: 'React', have: true, proficiency: 2)

      expect(service.effective_skills).not_to include('react')
    end

    it 'excludes skills with nil proficiency' do
      JobSkillAssessment.create!(job_posting: job_posting, skill_name: 'React', have: true, proficiency: nil)

      expect(service.effective_skills).not_to include('react')
    end

    it 'excludes skills marked as dont have' do
      JobSkillAssessment.create!(job_posting: job_posting, skill_name: 'ruby', have: false)

      expect(service.effective_skills).not_to include('ruby')
    end

    it 'combines verified and job-specific skills correctly' do
      JobSkillAssessment.create!(job_posting: job_posting, skill_name: 'React', have: true, proficiency: 4)
      JobSkillAssessment.create!(job_posting: job_posting, skill_name: 'rails', have: false)

      expected = %w[javascript react ruby] # ruby included (verified), rails excluded (dont have), react added (above threshold)
      expect(service.effective_skills).to match_array(expected)
    end
  end

  describe '#skill_summary' do
    it 'returns correct counts' do
      JobSkillAssessment.create!(job_posting: job_posting, skill_name: 'React', have: true, proficiency: 4)
      JobSkillAssessment.create!(job_posting: job_posting, skill_name: 'rails', have: false)

      summary = service.skill_summary
      expect(summary[:verified_count]).to eq(3)
      expect(summary[:included_count]).to eq(1)
      expect(summary[:excluded_count]).to eq(1)
      expect(summary[:total_effective]).to eq(3) # javascript + ruby + react (rails excluded)
    end

    it 'handles nil proficiency correctly' do
      JobSkillAssessment.create!(job_posting: job_posting, skill_name: 'React', have: true, proficiency: nil)

      summary = service.skill_summary
      expect(summary[:included_count]).to eq(0) # nil proficiency should not be included
    end
  end
end
