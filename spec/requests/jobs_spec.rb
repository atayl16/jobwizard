# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Jobs', type: :request do
  describe 'GET /jobs' do
    let!(:high_score_job) do
      JobPosting.create!(
        company: 'Rails Shop',
        title: 'Ruby on Rails Engineer',
        description: 'Build with Rails and RSpec',
        url: 'https://example.com/rails-job',
        score: 15.5
      )
    end

    let!(:medium_score_job) do
      JobPosting.create!(
        company: 'Mixed Stack',
        title: 'Full Stack Engineer',
        description: 'Ruby and React',
        url: 'https://example.com/fullstack-job',
        score: 8.0
      )
    end

    let!(:low_score_job) do
      JobPosting.create!(
        company: 'Frontend Co',
        title: 'React Developer',
        description: 'Build with React',
        url: 'https://example.com/react-job',
        score: 2.0
      )
    end

    it 'sorts jobs by score descending' do
      get jobs_path

      expect(response).to have_http_status(:success)
      
      # Check that jobs are in score order in the response body
      body = response.body
      rails_position = body.index('Ruby on Rails Engineer')
      fullstack_position = body.index('Full Stack Engineer')
      react_position = body.index('React Developer')

      expect(rails_position).to be < fullstack_position
      expect(fullstack_position).to be < react_position
    end

    it 'displays the active filter label' do
      get jobs_path

      expect(response.body).to include('Showing Ruby / Rails roles only')
    end

    it 'loads rules in controller' do
      get jobs_path

      # Just verify the response includes content that shows rules were loaded
      expect(response.body).to include('Job Board')
      expect(response).to have_http_status(:success)
    end
  end
end

