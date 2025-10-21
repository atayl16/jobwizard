# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobWizard::JobFilter do
  let(:rules_hash) do
    {
      'include_keywords' => ['ruby', 'rails', 'ruby on rails'],
      'exclude_keywords' => ['accountant', 'accounting', 'tax', 'analyst', 'project manager'],
      'require_include_match' => true
    }
  end

  let(:filter) { described_class.new(rules_hash) }

  describe '#keep?' do
    context 'with Ruby/Rails jobs' do
      it 'keeps Software Engineer (Ruby on Rails)' do
        expect(filter.keep?(
          title: 'Software Engineer (Ruby on Rails)',
          description: 'Build web applications with Rails, ActiveRecord, RSpec'
        )).to be true
      end

      it 'keeps Rails Engineer with Ruby in description' do
        expect(filter.keep?(
          title: 'Rails Engineer',
          description: 'Strong Ruby and Rails experience required'
        )).to be true
      end

      it 'keeps Backend Ruby Engineer' do
        expect(filter.keep?(
          title: 'Backend Ruby Engineer',
          description: 'Build APIs with Ruby and Postgres. Sidekiq experience a plus.'
        )).to be true
      end
    end

    context 'with non-dev roles' do
      it 'drops Senior Tax Technology Analyst' do
        expect(filter.keep?(
          title: 'Senior Tax Technology Analyst',
          description: 'Process tax returns, filing compliance'
        )).to be false
      end

      it 'drops Workforce Project Management Analyst' do
        expect(filter.keep?(
          title: 'Workforce Project Management Analyst',
          description: 'PMO coordination and operations'
        )).to be false
      end

      it 'drops Accounting Software Engineer' do
        expect(filter.keep?(
          title: 'Accounting Software Engineer',
          description: 'Build accounting software with Python'
        )).to be false
      end

      it 'drops Project Manager role' do
        expect(filter.keep?(
          title: 'Senior Project Manager',
          description: 'Lead agile teams and coordinate releases'
        )).to be false
      end
    end

    context 'with edge cases' do
      it 'requires include match when flag is true' do
        expect(filter.keep?(
          title: 'Software Engineer',
          description: 'Build great products with modern tech stack'
        )).to be false # No Ruby/Rails mentioned
      end

      it 'handles punctuation variations correctly' do
        expect(filter.keep?(
          title: 'Ruby-on-Rails Developer',
          description: 'Rails/Ruby expert needed'
        )).to be true
      end

      it 'handles case insensitivity' do
        expect(filter.keep?(
          title: 'RUBY ENGINEER',
          description: 'RAILS experience required'
        )).to be true
      end
    end

    context 'when require_include_match is false' do
      let(:filter) do
        described_class.new({
          'include_keywords' => ['ruby', 'rails'],
          'exclude_keywords' => ['accountant'],
          'require_include_match' => false
        })
      end

      it 'keeps jobs without include keywords if no exclude matches' do
        expect(filter.keep?(
          title: 'Software Engineer',
          description: 'Build with Python and Django'
        )).to be true
      end

      it 'still drops jobs with exclude keywords' do
        expect(filter.keep?(
          title: 'Software Accountant',
          description: 'Build accounting software'
        )).to be false
      end
    end
  end

  describe 'word-aware matching' do
    it 'does not match "ruby" inside "cherubyanything"' do
      filter = described_class.new({
        'include_keywords' => ['ruby'],
        'exclude_keywords' => [],
        'require_include_match' => true
      })

      expect(filter.keep?(
        title: 'Cherubyanything Engineer',
        description: 'Work on cherubyanything projects'
      )).to be false
    end

    it 'does not match "analyst" inside "analysis"' do
      filter = described_class.new({
        'include_keywords' => ['ruby'],
        'exclude_keywords' => ['analyst'],
        'require_include_match' => false
      })

      expect(filter.keep?(
        title: 'Ruby Data Analysis Engineer',
        description: 'Perform data analysis with Ruby'
      )).to be true # "analysis" shouldn't trigger "analyst" exclude
    end
  end
end

