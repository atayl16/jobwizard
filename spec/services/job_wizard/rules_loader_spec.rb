RSpec.describe JobWizard::RulesLoader, type: :service do
  let(:loader) { described_class.new }

  describe '#filters' do
    it 'returns default filters when no YAML file exists' do
      allow(File).to receive(:exist?).and_return(false)

      expect(loader.filters['required_keywords']).to eq(%w[ruby rails])
      expect(loader.filters['excluded_keywords']).to eq(%w[php dotnet .net golang cobol])
      expect(loader.filters['require_no_security_clearance']).to be true
    end

    it 'merges YAML data with defaults' do
      yaml_content = {
        'filters' => {
          'required_keywords' => ['python'],
          'custom_setting' => 'value'
        }
      }
      allow(YAML).to receive(:safe_load_file).and_return(yaml_content)

      filters = loader.filters
      expect(filters['required_keywords']).to include('python', 'ruby', 'rails')
      expect(filters['custom_setting']).to eq('value')
    end
  end

  describe '#compile_regex_patterns' do
    it 'handles plain strings as case-insensitive regex' do
      patterns = %w[test example]
      compiled = loader.compile_regex_patterns(patterns)

      expect(compiled[0]).to be_a(Regexp)
      expect('TEST').to match(compiled[0])
    end

    it 'handles regex patterns with flags' do
      patterns = ['/^test$/i', '/example/']
      compiled = loader.compile_regex_patterns(patterns)

      expect(compiled[0]).to be_a(Regexp)
      expect('TEST').to match(compiled[0])
      expect('TESTING').not_to match(compiled[0])
    end

    it 'handles invalid regex gracefully' do
      patterns = ['/invalid[regex/']
      compiled = loader.compile_regex_patterns(patterns)

      expect(compiled[0]).to be_a(Regexp)
      expect('invalid[regex').to match(compiled[0])
    end
  end

  describe 'filter accessors' do
    it 'provides access to specific filter categories' do
      expect(loader.company_blocklist).to be_an(Array)
      expect(loader.content_blocklist).to include('nsfw', 'gambling')
      expect(loader.required_keywords).to include('ruby', 'rails')
      expect(loader.excluded_keywords).to include('php', 'dotnet')
    end

    it 'filters out blank company blocklist entries' do
      allow(loader).to receive(:filters).and_return({
                                                      'company_blocklist' => ['ValidCompany', '', 'AnotherCompany']
                                                    })

      expect(loader.company_blocklist).to eq(%w[ValidCompany AnotherCompany])
    end

    it 'merges YAML and DB company blocklists' do
      allow(loader).to receive(:filters).and_return({
                                                      'company_blocklist' => ['YamlCompany']
                                                    })
      allow(BlockedCompany).to receive(:pluck).with(:name).and_return(['DbCompany'])

      expect(loader.company_blocklist).to include('YamlCompany', 'DbCompany')
    end
  end
end
