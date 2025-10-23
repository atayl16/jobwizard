require 'rails_helper'

RSpec.describe 'Navigation', type: :system do
  it 'allows clicking the app title to return to dashboard' do
    visit jobs_path

    # Verify we're on jobs page
    expect(page).to have_content('Job Board')

    # Click the JobWizard title
    click_link 'JobWizard'

    # Should redirect to root path (dashboard)
    expect(page).to have_current_path(root_path)
  end

  it 'shows navigation links in header' do
    visit root_path

    expect(page).to have_link('Jobs')
    expect(page).to have_link('New Application')
    expect(page).to have_link('Settings')
  end
end
