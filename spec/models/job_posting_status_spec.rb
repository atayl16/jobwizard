# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobPosting, type: :model do
  describe '#generated_today?' do
    let(:job) { described_class.create!(title: 'Test', company: 'Test Co', url: 'https://example.com/job', description: 'Test') }

    it 'returns true when exported_at is today' do
      job.update!(exported_at: Time.current)
      expect(job.generated_today?).to be true
    end

    it 'returns false when exported_at is yesterday' do
      job.update!(exported_at: 1.day.ago)
      expect(job.generated_today?).to be false
    end

    it 'returns false when exported_at is nil' do
      expect(job.generated_today?).to be false
    end
  end

  describe '#latest_application' do
    let(:job) { described_class.create!(title: 'Test', company: 'Test Co', url: 'https://example.com/job', description: 'Test') }

    it 'returns the most recent application' do
      Application.create!(company: 'Test', role: 'Role', job_description: 'Test', status: :generated,
                          job_posting: job)
      app2 = Application.create!(company: 'Test', role: 'Role', job_description: 'Test', status: :generated,
                                 job_posting: job)

      expect(job.latest_application).to eq(app2)
    end

    it 'returns nil when no applications exist' do
      expect(job.latest_application).to be_nil
    end
  end

  describe '#has_pdfs?' do
    let(:job) { described_class.create!(title: 'Test', company: 'Test Co', url: 'https://example.com/job', description: 'Test') }

    it 'returns true when any generated application exists' do
      Application.create!(company: 'Test', role: 'Role', job_description: 'Test', status: :generated, job_posting: job)
      expect(job.has_pdfs?).to be true
    end

    it 'returns false when no generated applications exist' do
      expect(job.has_pdfs?).to be false
    end

    it 'returns false when applications exist but are not generated' do
      Application.create!(company: 'Test', role: 'Role', job_description: 'Test', status: :draft, job_posting: job)
      expect(job.has_pdfs?).to be false
    end
  end
end
