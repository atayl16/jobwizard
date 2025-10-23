require 'rails_helper'

RSpec.describe JobPosting, type: :model do
  describe 'status' do
    it 'defaults to suggested' do
      job = described_class.new(title: 'Test', company: 'Test Co')
      expect(job.status).to eq('suggested')
    end

    it 'has correct enum values' do
      expect(described_class.statuses).to eq({
                                               'suggested' => 'suggested',
                                               'applied' => 'applied',
                                               'ignored' => 'ignored',
                                               'exported' => 'exported'
                                             })
    end
  end

  describe 'scopes' do
    let!(:suggested_job) { described_class.create!(title: 'Test', company: 'Test', url: 'https://example.com/1', status: 'suggested', description: 'Test job') }
    let!(:applied_job) { described_class.create!(title: 'Test2', company: 'Test2', url: 'https://example.com/2', status: 'applied', description: 'Test job 2') }

    it 'active_board returns only suggested jobs' do
      expect(described_class.active_board).to contain_exactly(suggested_job)
    end
  end

  describe '#mark_applied!' do
    it 'sets status to applied and applied_at timestamp' do
      job = described_class.create!(title: 'Test', company: 'Test', url: 'https://example.com/3', description: 'Test')
      job.mark_applied!
      expect(job.status).to eq('applied')
      expect(job.applied_at).to be_present
      expect(job.applied_at).to be_within(1.second).of(Time.current)
    end
  end

  describe '#mark_exported!' do
    it 'sets status to exported and exported_at timestamp' do
      job = described_class.create!(title: 'Test', company: 'Test', url: 'https://example.com/4', description: 'Test')
      job.mark_exported!
      expect(job.status).to eq('exported')
      expect(job.exported_at).to be_present
      expect(job.exported_at).to be_within(1.second).of(Time.current)
    end
  end
end
