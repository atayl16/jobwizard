# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobWizard::SourceLoader do
  describe '.load_sources' do
    it 'loads sources from YAML' do
      sources = described_class.load_sources
      expect(sources).to be_an(Array)
      expect(sources.first).to respond_to(:provider, :slug, :name, :active?)
    end

    it 'returns empty array if file not found' do
      allow(File).to receive(:exist?).and_return(false)
      allow(YAML).to receive(:load_file).and_raise(Errno::ENOENT)
      
      expect(described_class.load_sources).to eq([])
    end
  end

  describe '.active_sources' do
    it 'returns only active sources' do
      sources = described_class.active_sources
      expect(sources.all?(&:active?)).to be true
    end
  end

  describe 'Source struct' do
    let(:source) { described_class::Source.new(provider: 'greenhouse', slug: 'test', name: 'Test', active: true) }

    it 'has required attributes' do
      expect(source.provider).to eq('greenhouse')
      expect(source.slug).to eq('test')
      expect(source.name).to eq('Test')
      expect(source.active?).to be true
    end
  end
end

