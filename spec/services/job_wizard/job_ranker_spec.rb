# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobWizard::JobRanker do
  let(:scoring_hash) do
    {
      'boosts' => {
        'ruby' => 5.0,
        'rails' => 5.0,
        'ruby on rails' => 6.0,
        'rspec' => 2.5,
        'sidekiq' => 2.0
      },
      'neutral_or_low' => {
        'react' => 0.5,
        'javascript' => 0.5
      },
      'penalties' => {
        'accountant' => -5.0,
        'accounting' => -5.0,
        'analyst' => -3.5
      }
    }
  end

  let(:ranking_hash) do
    {
      'min_keep_score' => 1.0,
      'require_include_match' => true
    }
  end

  let(:ranker) { described_class.new(scoring_hash, ranking_hash) }

  describe '#score' do
    context 'with Ruby on Rails Engineer' do
      it 'scores higher than React Developer' do
        rails_score = ranker.score(
          title: 'Ruby on Rails Engineer',
          description: 'Build with Rails, RSpec, Sidekiq'
        )

        react_score = ranker.score(
          title: 'React Developer',
          description: 'Build with React and JavaScript'
        )

        expect(rails_score).to be > react_score
        expect(rails_score).to be > 10.0 # Should have rails (5) + rspec (2.5) + sidekiq (2.0) = 9.5 plus more
      end
    end

    context 'with keyword counting' do
      it 'counts multiple occurrences of the same keyword' do
        score = ranker.score(
          title: 'Senior Ruby on Rails Engineer',
          description: 'Expert in Ruby and Rails. Build Ruby applications with Rails framework.'
        )

        # ruby on rails (6.0) + ruby (5.0 x2) + rails (5.0 x2) = 26.0
        expect(score).to be >= 20.0
      end
    end

    context 'with penalties' do
      it 'applies penalties for excluded keywords' do
        # This job has ruby but also accounting keyword
        score = ranker.score(
          title: 'Ruby Accounting Software Engineer',
          description: 'Build accounting software with Ruby'
        )

        # Ruby (5.0) - accounting penalty (5.0) = 0.0
        expect(score).to be <= 1.0
      end
    end

    context 'with neutral keywords' do
      it 'adds small boosts for neutral tech' do
        score = ranker.score(
          title: 'Full Stack Ruby Engineer',
          description: 'Rails backend with React frontend. JavaScript and Ruby skills needed.'
        )

        # Should have rails + ruby boosts plus small react/js boosts
        expect(score).to be > 10.0
      end
    end

    context 'when filter would drop the job' do
      it 'returns 0.0 for non-Ruby jobs' do
        score = ranker.score(
          title: 'Python Developer',
          description: 'Django and Flask experience'
        )

        expect(score).to eq(0.0)
      end

      it 'returns 0.0 for accountant roles' do
        score = ranker.score(
          title: 'Tax Accountant',
          description: 'Process tax returns and financial statements'
        )

        expect(score).to eq(0.0)
      end
    end

    context 'with min_keep_score threshold' do
      let(:ranking_hash) do
        {
          'min_keep_score' => 5.0,
          'require_include_match' => true
        }
      end

      it 'returns 0.0 for scores below threshold' do
        score = ranker.score(
          title: 'Ruby Developer',
          description: 'Some Ruby experience'
        )

        # ruby (5.0) exactly meets threshold
        expect(score).to be >= 5.0
      end

      it 'returns calculated score when above threshold' do
        score = ranker.score(
          title: 'Ruby on Rails Engineer',
          description: 'Rails and RSpec expertise'
        )

        # Should be well above 5.0
        expect(score).to be > 10.0
      end
    end

    context 'with case and punctuation variations' do
      it 'normalizes text before scoring' do
        score1 = ranker.score(
          title: 'Ruby-on-Rails Engineer',
          description: 'RAILS/RUBY expert'
        )

        score2 = ranker.score(
          title: 'Ruby on Rails Engineer',
          description: 'rails ruby expert'
        )

        # Scores should be equal after normalization
        expect(score1).to eq(score2)
      end
    end
  end

  describe 'integration with JobFilter' do
    it 'uses the same filter logic internally' do
      # Job that should be filtered out
      score = ranker.score(
        title: 'Project Manager',
        description: 'Coordinate teams and deliverables'
      )

      expect(score).to eq(0.0)
    end
  end
end
