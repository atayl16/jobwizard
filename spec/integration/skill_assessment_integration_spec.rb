RSpec.describe 'Skill Assessment Integration', type: :request do
  let(:job_posting) do
    JobPosting.create!(title: 'Ruby Developer', company: 'Test Co',
                       description: 'We need Ruby, Rails, and JavaScript skills', url: 'https://example.com/job/1')
  end

  before do
    # Mock YAML data
    allow(File).to receive(:exist?).and_return(true)
    allow(YAML).to receive(:safe_load_file).and_return({
                                                         'skills' => [
                                                           { 'name' => 'Ruby' },
                                                           { 'name' => 'Rails' }
                                                         ]
                                                       })
  end

  it 'integrates skill assessments with resume building' do
    # Set up skill assessments
    JobSkillAssessment.create!(job_posting: job_posting, skill_name: 'ruby', have: true, proficiency: 4)
    JobSkillAssessment.create!(job_posting: job_posting, skill_name: 'rails', have: true, proficiency: 5)
    JobSkillAssessment.create!(job_posting: job_posting, skill_name: 'javascript', have: false)

    # Test effective skills service
    service = JobWizard::EffectiveSkillsService.new(job_posting)
    effective_skills = service.effective_skills

    expect(effective_skills).to include('ruby', 'rails')
    expect(effective_skills).not_to include('javascript')

    # Test skill summary
    summary = service.skill_summary
    expect(summary[:verified_count]).to eq(2)
    expect(summary[:included_count]).to eq(2)
    expect(summary[:excluded_count]).to eq(1)
    expect(summary[:total_effective]).to eq(2)
  end

  it 'shows skill assessment UI on job show page' do
    get job_path(job_posting)

    expect(response).to be_successful
    expect(response.body).to include('Skill Assessment')
    expect(response.body).to include('ruby')
    expect(response.body).to include('rails')
    expect(response.body).to include('javascript')
  end
end
