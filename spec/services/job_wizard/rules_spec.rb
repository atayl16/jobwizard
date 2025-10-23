# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobWizard::Rules do
  let(:temp_rules_path) { Rails.root.join('tmp/test_rules.yml') }

  after do
    FileUtils.rm_f(temp_rules_path)
    described_class.reset!
  end

  describe '.current' do
    it 'returns a singleton instance' do
      instance1 = described_class.current
      instance2 = described_class.current
      expect(instance1).to be(instance2)
    end
  end

  describe '.reset!' do
    it 'clears the singleton instance' do
      instance1 = described_class.current
      described_class.reset!
      instance2 = described_class.current
      expect(instance1).not_to be(instance2)
    end
  end

  describe '#job_filters' do
    context 'when primary key exists' do
      let(:rules_content) do
        <<~YAML
          job_filters:
            include_keywords: ['primary', 'key']
          job_filters_ruby:
            include_keywords: ['fallback', 'key']
        YAML
      end

      before { File.write(temp_rules_path, rules_content) }

      it 'returns the primary key value' do
        rules = described_class.new(temp_rules_path)
        expect(rules.job_filters['include_keywords']).to eq(%w[primary key])
      end
    end

    context 'when only fallback key exists' do
      let(:rules_content) do
        <<~YAML
          job_filters_ruby:
            include_keywords: ['fallback', 'key']
        YAML
      end

      before { File.write(temp_rules_path, rules_content) }

      it 'returns the fallback key value' do
        rules = described_class.new(temp_rules_path)
        expect(rules.job_filters['include_keywords']).to eq(%w[fallback key])
      end
    end

    context 'when neither key exists' do
      let(:rules_content) { 'some_other_key: value' }

      before { File.write(temp_rules_path, rules_content) }

      it 'returns empty hash' do
        rules = described_class.new(temp_rules_path)
        expect(rules.job_filters).to eq({})
      end
    end
  end

  describe '#scoring' do
    context 'when primary key exists' do
      let(:rules_content) do
        <<~YAML
          scoring:
            boosts:
              primary: 10.0
          scoring_ruby:
            boosts:
              fallback: 5.0
        YAML
      end

      before { File.write(temp_rules_path, rules_content) }

      it 'prefers primary key over fallback' do
        rules = described_class.new(temp_rules_path)
        expect(rules.scoring['boosts']).to eq({ 'primary' => 10.0 })
      end
    end

    context 'when only fallback exists' do
      let(:rules_content) do
        <<~YAML
          scoring_ruby:
            boosts:
              ruby: 5.0
        YAML
      end

      before { File.write(temp_rules_path, rules_content) }

      it 'falls back to scoring_ruby' do
        rules = described_class.new(temp_rules_path)
        expect(rules.scoring['boosts']).to eq({ 'ruby' => 5.0 })
      end
    end
  end

  describe '#ranking' do
    it 'prefers primary key over fallback' do
      rules_content = <<~YAML
        ranking:
          min_keep_score: 2.0
        ranking_ruby:
          min_keep_score: 1.0
      YAML
      File.write(temp_rules_path, rules_content)

      rules = described_class.new(temp_rules_path)
      expect(rules.ranking['min_keep_score']).to eq(2.0)
    end
  end

  describe '#ui' do
    it 'prefers primary key over fallback' do
      rules_content = <<~YAML
        ui:
          active_filter_label: "Primary Label"
        ui_ruby:
          active_filter_label: "Fallback Label"
      YAML
      File.write(temp_rules_path, rules_content)

      rules = described_class.new(temp_rules_path)
      expect(rules.ui['active_filter_label']).to eq('Primary Label')
    end
  end

  describe 'existing rules compatibility' do
    let(:rules_content) do
      <<~YAML
        warnings:
          us_only_role:
            message: "US citizen required"
        blocking:
          unpaid:
            message: "Unpaid position"
        info:
          equity_mentioned:
            message: "Equity mentioned"
      YAML
    end

    before { File.write(temp_rules_path, rules_content) }

    it 'still provides access to warnings' do
      rules = described_class.new(temp_rules_path)
      expect(rules.warnings).to have_key('us_only_role')
    end

    it 'still provides access to blocking' do
      rules = described_class.new(temp_rules_path)
      expect(rules.blocking).to have_key('unpaid')
    end

    it 'still provides access to info' do
      rules = described_class.new(temp_rules_path)
      expect(rules.info).to have_key('equity_mentioned')
    end
  end
end
