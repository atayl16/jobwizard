require 'rails_helper'

RSpec.describe 'JobSkillAssessments', type: :request do
  let(:job_posting) { JobPosting.create!(title: 'Test Job', company: 'Test Co', url: 'https://example.com/job', description: 'Test description') }

  describe 'POST /jobs/:job_posting_id/job_skill_assessments' do
    it 'creates a new skill assessment' do
      post job_job_skill_assessments_path(job_posting), params: {
        job_skill_assessment: {
          skill_name: 'ruby',
          have: true,
          proficiency: 4
        }
      }

      expect(response).to redirect_to(job_path(job_posting))
      expect(flash[:notice]).to eq('Skill assessment saved')

      assessment = job_posting.job_skill_assessments.find_by(skill_name: 'ruby')
      expect(assessment).to be_present
      expect(assessment.have).to be true
      expect(assessment.proficiency).to eq(4)
    end

    it 'handles validation errors' do
      post job_job_skill_assessments_path(job_posting), params: {
        job_skill_assessment: {
          skill_name: '',
          have: true,
          proficiency: 4
        }
      }

      expect(response).to redirect_to(job_path(job_posting))
      expect(flash[:alert]).to eq('Failed to save skill assessment')
    end
  end

  describe 'PATCH /jobs/:job_posting_id/job_skill_assessments/:id' do
    let!(:assessment) do
      JobSkillAssessment.create!(
        job_posting: job_posting,
        skill_name: 'ruby',
        have: true,
        proficiency: 3
      )
    end

    it 'updates an existing skill assessment' do
      patch job_job_skill_assessment_path(job_posting, assessment), params: {
        job_skill_assessment: {
          skill_name: 'ruby',
          have: true,
          proficiency: 5
        }
      }

      expect(response).to redirect_to(job_path(job_posting))
      expect(flash[:notice]).to eq('Skill assessment updated')

      assessment.reload
      expect(assessment.proficiency).to eq(5)
    end
  end
end
