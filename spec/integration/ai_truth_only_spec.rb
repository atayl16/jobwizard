# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Writer Truth-Only Guardrails', type: :integration do
  let(:mock_client) { double('OpenAI::Client') }
  let(:profile_yaml) { Rails.root.join('config/job_wizard/profile.yml').read }
  let(:experience_yaml) { Rails.root.join('config/job_wizard/experience.yml').read }

  before do
    allow(JobWizard).to receive(:openai_client).and_return(mock_client)
  end

  describe 'unverified skills handling' do
    let(:jd_with_fake_skills) do
      <<~JD
        Senior Rails Engineer

        Requirements:
        - Ruby on Rails (expert level)
        - PostgreSQL
        - Kubernetes Operators (must have production experience)
        - Terraform Enterprise
        - GraphQL
      JD
    end

    context 'when job description contains skills not in experience.yml' do
      let(:ai_response) do
        {
          'choices' => [
            {
              'message' => {
                'content' => {
                  cover_letter: 'I have extensive experience with Ruby on Rails and PostgreSQL...',
                  unverified_skills: ['Kubernetes Operators', 'Terraform Enterprise']
                }.to_json
              }
            }
          ]
        }
      end

      before do
        allow(mock_client).to receive(:chat).and_return(ai_response)
      end

      it 'returns unverified skills in response' do
        writer = JobWizard::Writers::OpenAiWriter.new(client: mock_client)

        result = writer.cover_letter(
          company: 'Test Corp',
          role: 'Senior Rails Engineer',
          jd_text: jd_with_fake_skills,
          profile: profile_yaml,
          experience: experience_yaml
        )

        expect(result[:unverified_skills]).to include('Kubernetes Operators')
        expect(result[:unverified_skills]).to include('Terraform Enterprise')
      end

      it 'does not include unverified skills in cover letter text' do
        writer = JobWizard::Writers::OpenAiWriter.new(client: mock_client)

        result = writer.cover_letter(
          company: 'Test Corp',
          role: 'Senior Rails Engineer',
          jd_text: jd_with_fake_skills,
          profile: profile_yaml,
          experience: experience_yaml
        )

        letter = result[:cover_letter]

        # Should include verified skills
        expect(letter).to include('Ruby')
        expect(letter).to include('PostgreSQL')

        # Should NOT mention unverified skills
        expect(letter).not_to include('Kubernetes Operators')
        expect(letter).not_to include('Terraform Enterprise')
      end

      it 'passes unverified skills through resume builder' do
        # Mock OpenAI to return unverified skills
        allow(mock_client).to receive(:chat).and_return(ai_response)
        allow(JobWizard::Writers::OpenAiWriter).to receive(:new).and_return(
          instance_double(
            JobWizard::Writers::OpenAiWriter,
            cover_letter: {
              cover_letter: 'Test letter',
              unverified_skills: ['Kubernetes Operators', 'Terraform']
            }
          )
        )

        # Set AI_WRITER to openai for this test
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('AI_WRITER').and_return('openai')
        allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('test-key')

        builder = JobWizard::ResumeBuilder.new(job_description: jd_with_fake_skills)

        # Build cover letter (which calls the AI writer)
        builder.build_cover_letter

        # Check unverified skills are tracked
        expect(builder.unverified_skills).to include('Kubernetes Operators')
      end
    end

    context 'system prompt enforcement' do
      it 'includes truth-only instructions in system prompt' do
        expect(mock_client).to receive(:chat) do |params|
          system_message = params[:parameters][:messages].find { |m| m[:role] == 'system' }
          system_content = system_message[:content]

          # Verify key truth-only phrases are present
          expect(system_content).to include('TRUTH-ONLY')
          expect(system_content).to include('NEVER invent')
          expect(system_content).to include('MUST ONLY use facts')
          expect(system_content).to include('unverified_skills')

          # Return valid response
          {
            'choices' => [
              {
                'message' => {
                  'content' => {
                    cover_letter: 'Test',
                    unverified_skills: []
                  }.to_json
                }
              }
            ]
          }
        end

        writer = JobWizard::Writers::OpenAiWriter.new(client: mock_client)
        writer.cover_letter(
          company: 'Test',
          role: 'Engineer',
          jd_text: 'Test JD',
          profile: profile_yaml,
          experience: experience_yaml
        )
      end
    end
  end

  describe 'fallback to template writer on error' do
    before do
      # Simulate AI failure
      allow(mock_client).to receive(:chat).and_raise(Faraday::Error.new('Network error'))
    end

    it 'returns error without crashing' do
      writer = JobWizard::Writers::OpenAiWriter.new(client: mock_client)

      result = writer.cover_letter(
        company: 'Test',
        role: 'Engineer',
        jd_text: 'Test JD',
        profile: profile_yaml,
        experience: experience_yaml
      )

      expect(result[:error]).to be_present
      expect(result[:cover_letter]).to be_nil
      expect(result[:unverified_skills]).to eq([])
    end

    it 'resume builder falls back to template writer' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('AI_WRITER').and_return('openai')
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('test-key')

      # Mock the factory to return OpenAiWriter class
      allow(JobWizard::WriterFactory).to receive(:build).and_return(JobWizard::Writers::OpenAiWriter)

      builder = JobWizard::ResumeBuilder.new(job_description: 'Test JD')

      # Should not raise error, should fall back to templates
      expect { builder.build_cover_letter }.not_to raise_error
    end
  end
end
