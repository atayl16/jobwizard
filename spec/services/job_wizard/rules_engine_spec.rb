RSpec.describe JobWizard::RulesEngine, type: :service do
  let(:engine) { described_class.new }
  let(:job_posting) do
    JobPosting.new(company: 'TestCorp', title: 'Ruby Developer', description: 'Looking for Ruby on Rails developer',
                   source: 'greenhouse')
  end

  describe '#should_reject?' do
    context 'company blocking' do
      it 'rejects jobs from blocked companies' do
        BlockedCompany.create!(name: 'TestCorp', pattern: false, reason: 'test')

        rejected, reasons = engine.should_reject?(job_posting)
        expect(rejected).to be true
        expect(reasons).to include("Company 'TestCorp' is blocked")
      end

      it 'allows jobs from non-blocked companies' do
        rejected, reasons = engine.should_reject?(job_posting)
        expect(rejected).to be false
        expect(reasons).not_to include(/blocked/)
      end
    end

    context 'content blocking' do
      it 'rejects jobs with NSFW content' do
        nsfw_job = JobPosting.new(company: 'TestCorp', title: 'NSFW Content Manager',
                                  description: 'Manage adult entertainment content')

        rejected, reasons = engine.should_reject?(nsfw_job)
        expect(rejected).to be true
        expect(reasons).to include('Contains blocked content')
      end

      it 'rejects jobs with gambling content' do
        gambling_job = JobPosting.new(company: 'TestCorp', title: 'Casino Developer',
                                      description: 'Develop gambling software')

        rejected, reasons = engine.should_reject?(gambling_job)
        expect(rejected).to be true
        expect(reasons).to include('Contains blocked content')
      end
    end

    context 'security clearance' do
      it 'rejects jobs requiring security clearance' do
        clearance_job = JobPosting.new(company: 'TestCorp', title: 'Developer',
                                       description: 'Must have active security clearance')

        rejected, reasons = engine.should_reject?(clearance_job)
        expect(rejected).to be true
        expect(reasons).to include('Requires security clearance')
      end

      it 'allows jobs mentioning background checks' do
        bg_job = JobPosting.new(company: 'TestCorp', title: 'Developer', description: 'Background check required')

        rejected, = engine.should_reject?(bg_job)
        expect(rejected).to be false
      end
    end

    context 'required keywords' do
      it 'rejects jobs missing Ruby/Rails keywords' do
        non_ruby_job = JobPosting.new(company: 'TestCorp', title: 'PHP Developer',
                                      description: 'Looking for PHP developer', source: 'greenhouse')

        rejected, reasons = engine.should_reject?(non_ruby_job)
        expect(rejected).to be true
        expect(reasons).to include('Missing required keywords (Ruby/Rails)')
      end

      it 'allows manually added jobs without Ruby/Rails' do
        manual_job = JobPosting.new(company: 'TestCorp', title: 'PHP Developer',
                                    description: 'Looking for PHP developer', source: 'manual')

        rejected, = engine.should_reject?(manual_job)
        expect(rejected).to be false
      end
    end

    context 'excluded keywords' do
      it 'rejects jobs with excluded keywords' do
        php_job = JobPosting.new(company: 'TestCorp', title: 'PHP Developer', description: 'Looking for PHP developer')

        rejected, reasons = engine.should_reject?(php_job)
        expect(rejected).to be true
        expect(reasons).to include('Contains excluded keywords')
      end
    end
  end

  describe '#recent_rejections' do
    it 'tracks rejection reasons' do
      BlockedCompany.create!(name: 'TestCorp', pattern: false, reason: 'test')
      engine.should_reject?(job_posting)

      rejections = engine.recent_rejections
      expect(rejections).to have(1).item
      expect(rejections.first[:company]).to eq('TestCorp')
      expect(rejections.first[:reasons]).to include("Company 'TestCorp' is blocked")
    end
  end
end
