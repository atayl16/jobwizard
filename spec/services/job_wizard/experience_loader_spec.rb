# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobWizard::ExperienceLoader do
  let(:temp_path) { Rails.root.join('tmp', 'test_experience.yml') }
  
  after do
    File.delete(temp_path) if File.exist?(temp_path)
  end

  describe 'Format 1: New array-of-hashes format' do
    let(:yaml_content) do
      <<~YAML
        skills:
          - name: "Ruby on Rails"
            level: "expert"
            context: "Primary framework for 5+ years"
          - name: "Docker"
            level: "intermediate"
            context: "Local development and debugging"
          - name: "Kubernetes"
            level: "basic"
            context: "Monitored pod health"
        positions: []
      YAML
    end

    before { File.write(temp_path, yaml_content) }

    it 'normalizes to array of hashes with symbols' do
      loader = described_class.new(temp_path)
      
      expect(loader.normalized_skills.length).to eq(3)
      expect(loader.normalized_skills[0]).to eq(
        name: 'Ruby on Rails',
        level: :expert,
        context: 'Primary framework for 5+ years'
      )
    end

    it 'returns all skill names' do
      loader = described_class.new(temp_path)
      
      expect(loader.all_skill_names).to include('ruby on rails', 'docker', 'kubernetes')
    end

    it 'gets level for skill' do
      loader = described_class.new(temp_path)
      
      expect(loader.level_for('Ruby on Rails')).to eq(:expert)
      expect(loader.level_for('Docker')).to eq(:intermediate)
      expect(loader.level_for('Kubernetes')).to eq(:basic)
    end

    it 'gets context for skill' do
      loader = described_class.new(temp_path)
      
      expect(loader.context_for('Docker')).to eq('Local development and debugging')
    end

    it 'checks skill existence' do
      loader = described_class.new(temp_path)
      
      expect(loader.has_skill?('Ruby on Rails')).to be true
      expect(loader.has_skill?('Python')).to be false
    end

    it 'groups skills by level' do
      loader = described_class.new(temp_path)
      by_level = loader.skills_by_level
      
      expect(by_level[:expert].length).to eq(1)
      expect(by_level[:intermediate].length).to eq(1)
      expect(by_level[:basic].length).to eq(1)
    end
  end

  describe 'Format 2: Old tiered format' do
    let(:yaml_content) do
      <<~YAML
        skills:
          proficient:
            - Ruby on Rails
            - PostgreSQL
          working_knowledge:
            - Docker
            - Kubernetes
          familiar:
            - Terraform
        positions: []
      YAML
    end

    before { File.write(temp_path, yaml_content) }

    it 'maps proficient to expert' do
      loader = described_class.new(temp_path)
      
      expect(loader.level_for('Ruby on Rails')).to eq(:expert)
      expect(loader.level_for('PostgreSQL')).to eq(:expert)
    end

    it 'maps working_knowledge to intermediate' do
      loader = described_class.new(temp_path)
      
      expect(loader.level_for('Docker')).to eq(:intermediate)
      expect(loader.level_for('Kubernetes')).to eq(:intermediate)
    end

    it 'maps familiar to basic' do
      loader = described_class.new(temp_path)
      
      expect(loader.level_for('Terraform')).to eq(:basic)
    end

    it 'has no contexts for old format' do
      loader = described_class.new(temp_path)
      
      expect(loader.context_for('Ruby on Rails')).to be_nil
    end
  end

  describe 'Format 3: Old flat array format' do
    let(:yaml_content) do
      <<~YAML
        skills:
          - Ruby on Rails
          - PostgreSQL
          - Docker
        positions: []
      YAML
    end

    before { File.write(temp_path, yaml_content) }

    it 'defaults all skills to intermediate' do
      loader = described_class.new(temp_path)
      
      expect(loader.level_for('Ruby on Rails')).to eq(:intermediate)
      expect(loader.level_for('PostgreSQL')).to eq(:intermediate)
      expect(loader.level_for('Docker')).to eq(:intermediate)
    end

    it 'recognizes all skills' do
      loader = described_class.new(temp_path)
      
      expect(loader.all_skill_names).to contain_exactly(
        'ruby on rails', 'postgresql', 'docker'
      )
    end
  end

  describe 'Level normalization aliases' do
    let(:yaml_content) do
      <<~YAML
        skills:
          - name: "Skill1"
            level: "proficient"
          - name: "Skill2"
            level: "working"
          - name: "Skill3"
            level: "beginner"
          - name: "Skill4"
            level: "advanced"
        positions: []
      YAML
    end

    before { File.write(temp_path, yaml_content) }

    it 'maps aliases correctly' do
      loader = described_class.new(temp_path)
      
      expect(loader.level_for('Skill1')).to eq(:expert)      # proficient
      expect(loader.level_for('Skill2')).to eq(:intermediate) # working
      expect(loader.level_for('Skill3')).to eq(:basic)       # beginner
      expect(loader.level_for('Skill4')).to eq(:expert)      # advanced
    end
  end

  describe 'Missing file' do
    it 'returns empty data gracefully' do
      loader = described_class.new('/tmp/nonexistent.yml')
      
      expect(loader.normalized_skills).to eq([])
      expect(loader.all_skill_names).to be_empty
      expect(loader.has_skill?('anything')).to be false
    end
  end

  describe 'not_claimed_skills' do
    let(:yaml_content) do
      <<~YAML
        skills:
          - name: "Ruby on Rails"
            level: "expert"
          - name: "Docker"
            level: "intermediate"
        not_claimed_skills:
          - "Kubernetes cluster administration"
          - "Kafka"
          - "Advanced SRE/production on-call ownership"
        positions: []
      YAML
    end

    before { File.write(temp_path, yaml_content) }

    it 'loads not_claimed_skills' do
      loader = described_class.new(temp_path)
      
      expect(loader.not_claimed_skills.length).to eq(3)
      expect(loader.not_claimed_skills).to include('Kafka')
    end

    it 'identifies skills as not_claimed' do
      loader = described_class.new(temp_path)
      
      expect(loader.not_claimed_skill?('Kafka')).to be true
      expect(loader.not_claimed_skill?('Kubernetes')).to be true # partial match
      expect(loader.not_claimed_skill?('Ruby on Rails')).to be false
    end

    it 'does not include not_claimed_skills in has_skill checks' do
      loader = described_class.new(temp_path)
      
      expect(loader.has_skill?('Kafka')).to be false
      expect(loader.has_skill?('Ruby on Rails')).to be true
    end
  end

  describe 'Skill aliases' do
    let(:yaml_content) do
      <<~YAML
        skills:
          - name: "Ruby on Rails"
            level: "expert"
          - name: "PostgreSQL"
            level: "intermediate"
          - name: "JavaScript"
            level: "expert"
          - name: "HTML/CSS"
            level: "intermediate"
        positions: []
      YAML
    end

    before { File.write(temp_path, yaml_content) }

    it 'normalizes skill aliases' do
      loader = described_class.new(temp_path)
      
      expect(loader.normalize_skill_name('Rails')).to eq('Ruby on Rails')
      expect(loader.normalize_skill_name('rails')).to eq('Ruby on Rails')
      expect(loader.normalize_skill_name('postgres')).to eq('PostgreSQL')
      expect(loader.normalize_skill_name('JS')).to eq('JavaScript')
      expect(loader.normalize_skill_name('html')).to eq('HTML/CSS')
    end

    it 'has_skill_with_alias checks using aliases' do
      loader = described_class.new(temp_path)
      
      expect(loader.has_skill_with_alias?('Rails')).to be true
      expect(loader.has_skill_with_alias?('rails')).to be true
      expect(loader.has_skill_with_alias?('postgres')).to be true
      expect(loader.has_skill_with_alias?('Python')).to be false
    end

    it 'preserves unknown skill names' do
      loader = described_class.new(temp_path)
      
      expect(loader.normalize_skill_name('Python')).to eq('Python')
      expect(loader.normalize_skill_name('Unknown Tech')).to eq('Unknown Tech')
    end
  end
end

