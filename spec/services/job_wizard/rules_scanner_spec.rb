# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobWizard::RulesScanner do
  let(:scanner) { described_class.new }

  describe '#scan' do
    context 'with empty or nil input' do
      it 'returns empty result for nil' do
        result = scanner.scan(nil)
        expect(result[:warnings]).to be_empty
        expect(result[:blocking]).to be_empty
        expect(result[:info]).to be_empty
      end

      it 'returns empty result for empty string' do
        result = scanner.scan('')
        expect(result[:warnings]).to be_empty
        expect(result[:blocking]).to be_empty
      end
    end

    context 'with US citizenship requirements' do
      let(:job_description) do
        'Must be a US citizen or authorized to work in the United States.'
      end

      it 'flags US citizenship as warning' do
        result = scanner.scan(job_description)
        expect(result[:warnings]).not_to be_empty
        us_flag = result[:warnings].find { |f| f[:rule] == 'us_only_role' }
        expect(us_flag).to be_present
        expect(us_flag[:message]).to include('citizenship')
      end
    end

    context 'with location restrictions' do
      let(:job_description) do
        'This is an on-site only position. Must be located in San Francisco.'
      end

      it 'flags location restrictions' do
        result = scanner.scan(job_description)
        location_flag = result[:warnings].find { |f| f[:rule] == 'location_restricted' }
        expect(location_flag).to be_present
      end
    end

    context 'with blocking issues' do
      it 'flags unpaid positions' do
        jd = 'This is an unpaid internship opportunity.'
        result = scanner.scan(jd)
        expect(result[:blocking]).not_to be_empty
        unpaid_flag = result[:blocking].find { |f| f[:rule] == 'unpaid' }
        expect(unpaid_flag).to be_present
      end

      it 'flags commission-only positions' do
        jd = 'Commission only, no base salary provided.'
        result = scanner.scan(jd)
        commission_flag = result[:blocking].find { |f| f[:rule] == 'commission_only' }
        expect(commission_flag).to be_present
      end
    end

    context 'with info flags' do
      it 'detects equity mentions' do
        jd = 'Competitive salary with equity and stock options.'
        result = scanner.scan(jd)
        equity_flag = result[:info].find { |f| f[:rule] == 'equity_mentioned' }
        expect(equity_flag).to be_present
      end

      it 'detects startup indicators' do
        jd = 'Fast-paced startup environment where you will wear many hats.'
        result = scanner.scan(jd)
        startup_flag = result[:info].find { |f| f[:rule] == 'startup_indicators' }
        expect(startup_flag).to be_present
      end
    end

    context 'with clean job description' do
      let(:clean_jd) do
        <<~JD
          Senior Ruby on Rails Developer
          
          We are seeking an experienced Rails developer for a remote position.
          You will work with PostgreSQL, Redis, and modern JavaScript frameworks.
          Competitive salary and benefits package.
        JD
      end

      it 'returns no warnings or blocking flags' do
        result = scanner.scan(clean_jd)
        expect(result[:warnings]).to be_empty
        expect(result[:blocking]).to be_empty
      end
    end

    context 'with skill verification' do
      let(:jd_with_mixed_skills) do
        <<~JD
          Looking for a developer with experience in:
          - Ruby on Rails (verified in experience.yml)
          - Rails (alias for Ruby on Rails, should be verified via alias)
          - Elixir and Phoenix (unverified - not in experience.yml)
          - Kafka (not_claimed - marked as exposure only)
        JD
      end

      it 'categorizes verified skills correctly' do
        result = scanner.scan(jd_with_mixed_skills)
        
        # Ruby on Rails should be verified (not in unverified or not_claimed)
        unverified_skills = result[:unverified_skills].map { |s| s[:skill] }
        not_claimed_skills = result[:not_claimed_skills].map { |s| s[:skill] }
        
        expect(unverified_skills).not_to include('Ruby on Rails')
        expect(not_claimed_skills).not_to include('Ruby on Rails')
      end

      it 'recognizes skill aliases as verified' do
        result = scanner.scan(jd_with_mixed_skills)
        
        # Rails should be recognized via alias
        unverified_skills = result[:unverified_skills].map { |s| s[:skill] }
        not_claimed_skills = result[:not_claimed_skills].map { |s| s[:skill] }
        
        expect(unverified_skills).not_to include('Rails')
        expect(not_claimed_skills).not_to include('Rails')
      end

      it 'identifies unverified skills' do
        result = scanner.scan(jd_with_mixed_skills)
        
        unverified_skills = result[:unverified_skills].map { |s| s[:skill] }
        
        expect(unverified_skills).to include('Elixir')
        expect(unverified_skills).to include('Phoenix')
      end

      it 'identifies not_claimed skills' do
        result = scanner.scan(jd_with_mixed_skills)
        
        not_claimed_skills = result[:not_claimed_skills].map { |s| s[:skill] }
        
        expect(not_claimed_skills).to include('Kafka')
      end

      it 'provides appropriate messages for not_claimed skills' do
        result = scanner.scan(jd_with_mixed_skills)
        
        kafka_flag = result[:not_claimed_skills].find { |s| s[:skill] == 'Kafka' }
        
        expect(kafka_flag[:message]).to include('exposure-only')
        expect(kafka_flag[:action]).to eq('mention_as_exposure')
      end

      it 'provides appropriate messages for unverified skills' do
        result = scanner.scan(jd_with_mixed_skills)
        
        elixir_flag = result[:unverified_skills].find { |s| s[:skill] == 'Elixir' }
        
        expect(elixir_flag[:message]).to be_present
        expect(elixir_flag[:action]).to be_present
      end
    end
  end

  describe '#blocking_flags?' do
    it 'returns true for unpaid position' do
      jd = 'Unpaid volunteer position'
      expect(scanner.blocking_flags?(jd)).to be true
    end

    it 'returns false for clean position' do
      jd = 'Great remote job with competitive salary'
      expect(scanner.blocking_flags?(jd)).to be false
    end
  end

  describe '#clean?' do
    it 'returns false when warnings exist' do
      jd = 'Must be US citizen'
      expect(scanner.clean?(jd)).to be false
    end

    it 'returns false when blocking flags exist' do
      jd = 'Unpaid internship'
      expect(scanner.clean?(jd)).to be false
    end

    it 'returns true for clean job description' do
      jd = 'Remote Rails developer position with great benefits'
      expect(scanner.clean?(jd)).to be true
    end
  end
end

