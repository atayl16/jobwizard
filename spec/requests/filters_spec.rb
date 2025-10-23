RSpec.describe 'Filters', type: :request do
  describe 'POST /filters/block_company' do
    it 'blocks a company successfully' do
      post filters_block_company_path, params: { company_name: 'TestCorp' }

      expect(response).to redirect_to(jobs_path)
      expect(flash[:notice]).to eq("Company 'TestCorp' blocked successfully")

      expect(BlockedCompany.find_by(name: 'TestCorp')).to be_present
    end

    it 'handles missing company name' do
      post filters_block_company_path, params: { company_name: '' }

      expect(response).to redirect_to(jobs_path)
      expect(flash[:alert]).to eq('Company name is required')
    end
  end
end

RSpec.describe 'Settings::Filters', type: :request do
  describe 'GET /settings/filters' do
    it 'shows the filters settings page' do
      get settings_filters_path

      expect(response).to be_successful
      expect(response.body).to include('Filter Settings')
      expect(response.body).to include('Blocked Companies')
    end
  end

  describe 'POST /settings/blocked_companies' do
    it 'creates a blocked company' do
      post settings_blocked_companies_path, params: {
        blocked_company: {
          name: 'TestCorp',
          pattern: false,
          reason: 'test'
        }
      }

      expect(response).to redirect_to(settings_filters_path)
      expect(flash[:notice]).to eq('Company blocked successfully')

      expect(BlockedCompany.find_by(name: 'TestCorp')).to be_present
    end
  end

  describe 'DELETE /settings/blocked_companies/:id' do
    let!(:blocked_company) { BlockedCompany.create!(name: 'TestCorp', pattern: false, reason: 'test') }

    it 'removes a blocked company' do
      delete settings_blocked_company_path(blocked_company)

      expect(response).to redirect_to(settings_filters_path)
      expect(flash[:notice]).to eq('Company unblocked successfully')

      expect(BlockedCompany.find_by(id: blocked_company.id)).to be_nil
    end
  end
end
