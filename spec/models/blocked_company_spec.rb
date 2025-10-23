RSpec.describe BlockedCompany, type: :model do
  describe '#matches?' do
    context 'with exact match (pattern: false)' do
      let(:blocked) { described_class.new(name: 'TestCorp', pattern: false) }

      it 'matches exact company name case-insensitively' do
        expect(blocked.matches?('TestCorp')).to be true
        expect(blocked.matches?('testcorp')).to be true
        expect(blocked.matches?('TESTCORP')).to be true
      end

      it 'does not match partial names' do
        expect(blocked.matches?('TestCorp Inc')).to be false
        expect(blocked.matches?('MyTestCorp')).to be false
      end
    end

    context 'with regex pattern (pattern: true)' do
      let(:blocked) { described_class.new(name: '^Test.*Corp$', pattern: true) }

      it 'matches using regex pattern' do
        expect(blocked.matches?('TestCorp')).to be true
        expect(blocked.matches?('TestCorp Inc')).to be false
        expect(blocked.matches?('MyTestCorp')).to be false
      end

      it 'handles invalid regex gracefully' do
        invalid_blocked = described_class.new(name: '[invalid', pattern: true)
        expect(invalid_blocked.matches?('[invalid')).to be true
        expect(invalid_blocked.matches?('valid')).to be false
      end
    end
  end

  describe '.matches_company?' do
    before do
      described_class.create!(name: 'BlockedCorp', pattern: false, reason: 'test')
      described_class.create!(name: '^Test.*$', pattern: true, reason: 'regex test')
    end

    it 'matches against any blocked company' do
      expect(described_class.matches_company?('BlockedCorp')).to be true
      expect(described_class.matches_company?('TestCorp')).to be true
      expect(described_class.matches_company?('ValidCorp')).to be false
    end

    it 'returns false for blank company names' do
      expect(described_class.matches_company?('')).to be false
      expect(described_class.matches_company?(nil)).to be false
    end
  end

  describe 'validations' do
    it 'requires name and reason' do
      blocked = described_class.new
      expect(blocked).not_to be_valid
      expect(blocked.errors[:name]).to include("can't be blank")
      expect(blocked.errors[:reason]).to include("can't be blank")
    end
  end
end
