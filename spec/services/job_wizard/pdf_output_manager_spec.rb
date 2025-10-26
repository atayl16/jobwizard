# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobWizard::PdfOutputManager do
  let(:company) { 'Acme Corp & Co.' }
  let(:role) { 'Senior Engineer (Remote)' }
  let(:timestamp) { Time.zone.parse('2025-01-15 10:30:00') }
  let(:manager) { described_class.new(company: company, role: role, timestamp: timestamp) }
  let(:pdf_content) { 'fake pdf content' }

  after do
    # Cleanup test directories
    FileUtils.rm_rf(manager.output_path)
    FileUtils.rm_rf(manager.tmp_path)
    latest_path = JobWizard::OUTPUT_ROOT.join('Latest')
    FileUtils.rm_f(latest_path) if File.symlink?(latest_path) || File.exist?(latest_path)
  end

  describe '#initialize' do
    it 'creates slugified paths from company and role' do
      expect(manager.output_path.to_s).to include('AcmeCorp')
      expect(manager.output_path.to_s).to include('SeniorEngineerRemote')
      expect(manager.output_path.to_s).to include('2025-01-15')
    end

    it 'creates parallel tmp path' do
      expect(manager.tmp_path.to_s).to include('tmp/outputs')
      expect(manager.tmp_path.to_s).to include('AcmeCorp')
      expect(manager.tmp_path.to_s).to include('SeniorEngineerRemote')
    end

    it 'handles special characters in company name' do
      manager = described_class.new(company: "O'Reilly & Associates!", role: 'Dev')
      expect(manager.output_path.to_s).to include('OReillyAssociates')
    end

    it 'handles long names by truncating' do
      long_name = 'A' * 150
      manager = described_class.new(company: long_name, role: 'Dev')
      slug = manager.output_path.to_s.split('/')[-3]
      expect(slug.length).to be <= 100
    end
  end

  describe '#ensure_directories!' do
    it 'creates output directory structure' do
      expect(File.exist?(manager.output_path)).to be false

      manager.ensure_directories!

      expect(File.exist?(manager.output_path)).to be true
      expect(File.directory?(manager.output_path)).to be true
    end

    it 'creates tmp directory structure' do
      expect(File.exist?(manager.tmp_path)).to be false

      manager.ensure_directories!

      expect(File.exist?(manager.tmp_path)).to be true
      expect(File.directory?(manager.tmp_path)).to be true
    end

    it 'returns self for method chaining' do
      expect(manager.ensure_directories!).to eq(manager)
    end
  end

  describe '#write_resume' do
    before { manager.ensure_directories! }

    it 'writes resume to output path' do
      manager.write_resume(pdf_content)

      expect(File.exist?(manager.resume_path)).to be true
      expect(File.read(manager.resume_path)).to eq(pdf_content)
    end

    it 'writes resume to tmp path for downloads' do
      manager.write_resume(pdf_content)

      expect(File.exist?(manager.tmp_resume_path)).to be true
      expect(File.read(manager.tmp_resume_path)).to eq(pdf_content)
    end

    it 'overwrites existing file' do
      manager.write_resume('old content')
      manager.write_resume(pdf_content)

      expect(File.read(manager.resume_path)).to eq(pdf_content)
    end
  end

  describe '#write_cover_letter' do
    before { manager.ensure_directories! }

    it 'writes cover letter to output path' do
      manager.write_cover_letter(pdf_content)

      expect(File.exist?(manager.cover_letter_path)).to be true
      expect(File.read(manager.cover_letter_path)).to eq(pdf_content)
    end

    it 'writes cover letter to tmp path' do
      manager.write_cover_letter(pdf_content)

      expect(File.exist?(manager.tmp_cover_letter_path)).to be true
      expect(File.read(manager.tmp_cover_letter_path)).to eq(pdf_content)
    end
  end

  describe '#update_latest_symlink!' do
    before { manager.ensure_directories! }

    let(:latest_path) { JobWizard::OUTPUT_ROOT.join('Latest') }

    it 'creates Latest symlink pointing to this application' do
      manager.update_latest_symlink!

      expect(File.symlink?(latest_path)).to be true
      expect(File.readlink(latest_path)).to eq(manager.output_path.to_s)
    end

    it 'updates existing symlink to point to new application' do
      # Create first application
      first_manager = described_class.new(
        company: 'First Co',
        role: 'Dev',
        timestamp: Time.zone.parse('2025-01-01')
      )
      first_manager.ensure_directories!
      first_manager.update_latest_symlink!

      expect(File.readlink(latest_path)).to eq(first_manager.output_path.to_s)

      # Create second application (current manager)
      manager.update_latest_symlink!

      expect(File.readlink(latest_path)).to eq(manager.output_path.to_s)
      expect(File.readlink(latest_path)).not_to eq(first_manager.output_path.to_s)

      # Cleanup first manager's path
      FileUtils.rm_rf(first_manager.output_path)
      FileUtils.rm_rf(first_manager.tmp_path)
    end

    it 'returns self for method chaining' do
      expect(manager.update_latest_symlink!).to eq(manager)
    end
  end

  describe '#pdfs_exist?' do
    before { manager.ensure_directories! }

    it 'returns false when no PDFs exist' do
      expect(manager.pdfs_exist?).to be false
    end

    it 'returns false when only resume exists' do
      manager.write_resume(pdf_content)
      expect(manager.pdfs_exist?).to be false
    end

    it 'returns false when only cover letter exists' do
      manager.write_cover_letter(pdf_content)
      expect(manager.pdfs_exist?).to be false
    end

    it 'returns true when both PDFs exist' do
      manager.write_resume(pdf_content)
      manager.write_cover_letter(pdf_content)
      expect(manager.pdfs_exist?).to be true
    end
  end

  describe '#display_path' do
    it 'returns human-readable path string' do
      expect(manager.display_path).to include('Applications')
      expect(manager.display_path).to include('AcmeCorp')
      expect(manager.display_path).to include('SeniorEngineerRemote')
      expect(manager.display_path).to include('2025-01-15')
    end
  end

  describe 'environment variable override' do
    let(:custom_root) { Pathname.new('/tmp/custom_job_wizard_test') }

    around do |example|
      original_output_root = JobWizard::OUTPUT_ROOT

      # Override the constant temporarily
      JobWizard.send(:remove_const, :OUTPUT_ROOT)
      JobWizard.const_set(:OUTPUT_ROOT, custom_root)

      example.run

      # Restore original constant
      JobWizard.send(:remove_const, :OUTPUT_ROOT)
      JobWizard.const_set(:OUTPUT_ROOT, original_output_root)

      # Cleanup custom directory
      FileUtils.rm_rf(custom_root)
    end

    it 'respects custom output root' do
      manager = described_class.new(company: 'Test', role: 'Dev')

      expect(manager.output_path.to_s).to start_with(custom_root.to_s)

      manager.ensure_directories!
      expect(File.exist?(manager.output_path)).to be true
    end
  end

  describe 'full workflow' do
    it 'creates complete application folder structure with symlink' do
      # Ensure directories
      manager.ensure_directories!

      # Write PDFs
      manager.write_resume('Resume content')
      manager.write_cover_letter('Cover letter content')

      # Update symlink
      manager.update_latest_symlink!

      # Verify everything exists
      expect(File.exist?(manager.resume_path)).to be true
      expect(File.exist?(manager.cover_letter_path)).to be true
      expect(File.exist?(manager.tmp_resume_path)).to be true
      expect(File.exist?(manager.tmp_cover_letter_path)).to be true
      expect(File.symlink?(JobWizard::OUTPUT_ROOT.join('Latest'))).to be true
      expect(manager.pdfs_exist?).to be true

      # Verify content
      expect(File.read(manager.resume_path)).to eq('Resume content')
      expect(File.read(manager.cover_letter_path)).to eq('Cover letter content')
    end
  end
end

