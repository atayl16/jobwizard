require 'rails_helper'

RSpec.describe 'Jobs', type: :request do
  describe 'PATCH /jobs/:id/applied' do
    let!(:job) { JobPosting.create!(title: 'Test Job', company: 'Test Co', url: 'https://example.com/1', description: 'Test') }

    it 'marks job as applied and redirects' do
      patch applied_job_path(job)

      expect(response).to redirect_to(jobs_path)
      expect(flash[:notice]).to eq('Job marked as applied')

      job.reload
      expect(job.status).to eq('applied')
      expect(job.applied_at).to be_present
    end
  end

  describe 'PATCH /jobs/:id/exported' do
    let!(:job) { JobPosting.create!(title: 'Test Job', company: 'Test Co', url: 'https://example.com/2', description: 'Test') }

    it 'marks job as exported and redirects' do
      patch exported_job_path(job)

      expect(response).to redirect_to(jobs_path)
      expect(flash[:notice]).to eq('Job marked as exported and hidden from suggestions')

      job.reload
      expect(job.status).to eq('exported')
      expect(job.exported_at).to be_present
    end
  end

  describe 'PATCH /jobs/:id/ignore' do
    let!(:job) { JobPosting.create!(title: 'Test Job', company: 'Test Co', url: 'https://example.com/3', description: 'Test') }

    it 'marks job as ignored and redirects' do
      patch ignore_job_path(job)

      expect(response).to redirect_to(jobs_path)
      expect(flash[:notice]).to eq('Job ignored')

      job.reload
      expect(job.status).to eq('ignored')
    end
  end

  describe 'GET /jobs' do
    let!(:suggested_job) { JobPosting.create!(title: 'Suggested Job Position', company: 'Test', url: 'https://example.com/4', description: 'Test', status: 'suggested') }
    let!(:applied_job) { JobPosting.create!(title: 'Applied Job Position', company: 'Test', url: 'https://example.com/5', description: 'Test', status: 'applied') }
    let!(:exported_job) { JobPosting.create!(title: 'Exported Job Position', company: 'Test', url: 'https://example.com/6', description: 'Test', status: 'exported') }
    let!(:ignored_job) { JobPosting.create!(title: 'Ignored Job Position', company: 'Test', url: 'https://example.com/7', description: 'Test', status: 'ignored') }

    it 'only shows suggested jobs' do
      get jobs_path

      expect(response.body).to include('Suggested Job Position')
      expect(response.body).not_to include('Applied Job Position')
      expect(response.body).not_to include('Exported Job Position')
      expect(response.body).not_to include('Ignored Job Position')
    end
  end

  describe 'GET /jobs/:id with invalid id' do
    it 'redirects to jobs index with alert message' do
      get job_path(id: 999_999)

      expect(response).to redirect_to(jobs_path)
      expect(flash[:alert]).to eq('Job posting not found or has been removed')
    end
  end
end
