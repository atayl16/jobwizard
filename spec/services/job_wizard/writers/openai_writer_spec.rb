# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobWizard::Writers::OpenAiWriter do
  let(:mock_client) { double('OpenAI::Client') }
  let(:profile_yaml) { Rails.root.join('config/job_wizard/profile.yml').read }
  let(:experience_yaml) { Rails.root.join('config/job_wizard/experience.yml').read }
  let(:jd_text) { 'We need a Senior Rails Engineer with Ruby, Rails, and PostgreSQL experience.' }
  let(:company) { 'Acme Corp' }
  let(:role) { 'Senior Rails Engineer' }

  before do
    # Stub network calls by default
    allow(JobWizard).to receive(:openai_client).and_return(mock_client)
  end

  describe '#initialize' do
    it 'raises error if client is nil' do
      expect do
        described_class.new(client: nil)
      end.to raise_error(JobWizard::Writers::OpenAiWriter::GenerationError, /client not available/)
    end

    it 'accepts custom model parameter' do
      writer = described_class.new(client: mock_client, model: 'gpt-4')
      expect(writer.model).to eq('gpt-4')
    end
  end

  describe '#cover_letter' do
    let(:writer) { described_class.new(client: mock_client) }

    context 'when OpenAI returns valid JSON' do
      let(:valid_response) do
        {
          'choices' => [
            {
              'message' => {
                'content' => {
                  cover_letter: "Dear Hiring Manager,\n\nI am excited to apply...",
                  unverified_skills: []
                }.to_json
              }
            }
          ]
        }
      end

      before do
        allow(mock_client).to receive(:chat).and_return(valid_response)
      end

      it 'returns cover letter text and unverified skills' do
        result = writer.cover_letter(
          company: company,
          role: role,
          jd_text: jd_text,
          profile: profile_yaml,
          experience: experience_yaml
        )

        expect(result).to be_a(Hash)
        expect(result[:cover_letter]).to include('Dear Hiring Manager')
        expect(result[:unverified_skills]).to eq([])
      end

      it 'calls OpenAI with correct parameters' do
        expect(mock_client).to receive(:chat).with(
          hash_including(
            parameters: hash_including(
              model: 'gpt-4o-mini',
              messages: array_including(
                hash_including(role: 'system'),
                hash_including(role: 'user')
              ),
              response_format: { type: 'json_object' }
            )
          )
        ).and_return(valid_response)

        writer.cover_letter(
          company: company,
          role: role,
          jd_text: jd_text,
          profile: profile_yaml,
          experience: experience_yaml
        )
      end
    end

    context 'when JD contains unverified skills' do
      let(:response_with_unverified) do
        {
          'choices' => [
            {
              'message' => {
                'content' => {
                  cover_letter: 'I have experience with Ruby and Rails...',
                  unverified_skills: ['Kubernetes Operators', 'Terraform']
                }.to_json
              }
            }
          ]
        }
      end

      before do
        allow(mock_client).to receive(:chat).and_return(response_with_unverified)
      end

      it 'returns unverified skills in response' do
        result = writer.cover_letter(
          company: company,
          role: role,
          jd_text: 'Need Ruby, Rails, Kubernetes Operators, Terraform',
          profile: profile_yaml,
          experience: experience_yaml
        )

        expect(result[:unverified_skills]).to include('Kubernetes Operators', 'Terraform')
      end

      it 'does not include unverified skills in cover letter text' do
        result = writer.cover_letter(
          company: company,
          role: role,
          jd_text: 'Need Ruby, Rails, Kubernetes Operators, Terraform',
          profile: profile_yaml,
          experience: experience_yaml
        )

        letter = result[:cover_letter]
        expect(letter).not_to include('Kubernetes Operators')
        expect(letter).not_to include('Terraform')
      end
    end

    context 'when OpenAI returns malformed JSON' do
      let(:malformed_response) do
        {
          'choices' => [
            {
              'message' => {
                'content' => 'This is not valid JSON {malformed'
              }
            }
          ]
        }
      end

      before do
        allow(mock_client).to receive(:chat).and_return(malformed_response)
      end

      it 'returns error without raising' do
        result = writer.cover_letter(
          company: company,
          role: role,
          jd_text: jd_text,
          profile: profile_yaml,
          experience: experience_yaml
        )

        expect(result[:error]).to be_present
        expect(result[:cover_letter]).to be_nil
        expect(result[:unverified_skills]).to eq([])
      end
    end

    context 'when OpenAI API fails' do
      before do
        allow(mock_client).to receive(:chat).and_raise(Faraday::Error.new('Network error'))
      end

      it 'returns error without raising' do
        result = writer.cover_letter(
          company: company,
          role: role,
          jd_text: jd_text,
          profile: profile_yaml,
          experience: experience_yaml
        )

        expect(result[:error]).to include('OpenAI API error')
        expect(result[:cover_letter]).to be_nil
      end
    end
  end

  describe '#resume_snippets' do
    let(:writer) { described_class.new(client: mock_client) }

    context 'when OpenAI returns valid JSON' do
      let(:valid_response) do
        {
          'choices' => [
            {
              'message' => {
                'content' => {
                  resume_snippets: [
                    'Built scalable Rails applications serving 1M+ users',
                    'Optimized PostgreSQL queries reducing load time by 40%',
                    'Led team of 5 engineers in agile development'
                  ],
                  unverified_skills: []
                }.to_json
              }
            }
          ]
        }
      end

      before do
        allow(mock_client).to receive(:chat).and_return(valid_response)
      end

      it 'returns resume snippets array' do
        result = writer.resume_snippets(
          company: company,
          role: role,
          jd_text: jd_text,
          profile: profile_yaml,
          experience: experience_yaml
        )

        expect(result[:resume_snippets]).to be_an(Array)
        expect(result[:resume_snippets].size).to eq(3)
        expect(result[:resume_snippets].first).to include('Built scalable Rails')
      end
    end

    context 'when API fails' do
      before do
        allow(mock_client).to receive(:chat).and_raise(OpenAI::Error.new('Rate limit'))
      end

      it 'returns error without crashing' do
        result = writer.resume_snippets(
          company: company,
          role: role,
          jd_text: jd_text,
          profile: profile_yaml,
          experience: experience_yaml
        )

        expect(result[:error]).to be_present
        expect(result[:resume_snippets]).to eq([])
      end
    end
  end

  describe 'truth-only guardrails' do
    let(:writer) { described_class.new(client: mock_client) }

    it 'includes truth-only instructions in system prompt' do
      expect(mock_client).to receive(:chat) do |params|
        system_message = params[:parameters][:messages].find { |m| m[:role] == 'system' }
        expect(system_message[:content]).to include('TRUTH-ONLY')
        expect(system_message[:content]).to include('NEVER invent')
        expect(system_message[:content]).to include('unverified_skills')

        {
          'choices' => [
            {
              'message' => {
                'content' => { cover_letter: 'Test', unverified_skills: [] }.to_json
              }
            }
          ]
        }
      end

      writer.cover_letter(
        company: company,
        role: role,
        jd_text: jd_text,
        profile: profile_yaml,
        experience: experience_yaml
      )
    end
  end
end
