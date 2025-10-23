require 'rails_helper'

RSpec.describe JobSkillAssessment, type: :model do
  let(:job_posting) { JobPosting.create!(title: 'Test', company: 'Test Co', url: 'https://example.com/job', description: 'Test') }

  describe 'validations' do
    it 'requires skill_name' do
      assessment = described_class.new(job_posting: job_posting, have: true)
      expect(assessment).not_to be_valid
      expect(assessment.errors[:skill_name]).to include("can't be blank")
    end

    it 'allows nil proficiency when have is true' do
      assessment = described_class.new(job_posting: job_posting, skill_name: 'ruby', have: true)
      expect(assessment).to be_valid
    end

    it 'requires proficiency to be 1-5 when have is true' do
      assessment = described_class.new(job_posting: job_posting, skill_name: 'ruby', have: true, proficiency: 6)
      expect(assessment).not_to be_valid
      expect(assessment.errors[:proficiency]).to include('is not included in the list')
    end

    it 'does not allow proficiency when have is false' do
      assessment = described_class.new(job_posting: job_posting, skill_name: 'ruby', have: false, proficiency: 3)
      expect(assessment).not_to be_valid
      expect(assessment.errors[:proficiency]).to include('must be blank')
    end

    it 'enforces uniqueness of skill_name per job_posting' do
      described_class.create!(job_posting: job_posting, skill_name: 'ruby', have: true, proficiency: 3)

      duplicate = described_class.new(job_posting: job_posting, skill_name: 'ruby', have: false)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:skill_name]).to include('has already been taken')
    end
  end

  describe 'normalization' do
    it 'normalizes skill_name to lowercase' do
      assessment = described_class.create!(job_posting: job_posting, skill_name: 'RUBY', have: true, proficiency: 3)
      expect(assessment.skill_name).to eq('ruby')
    end
  end
end
