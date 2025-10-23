class SettingsController < ApplicationController
  def filters
    @blocked_companies = BlockedCompany.order(:name)
    @rules_loader = JobWizard::RulesLoader.new
  end

  def create_blocked_company
    @blocked_company = BlockedCompany.new(blocked_company_params)

    if @blocked_company.save
      redirect_to settings_filters_path, notice: 'Company blocked successfully'
    else
      @blocked_companies = BlockedCompany.order(:name)
      @rules_loader = JobWizard::RulesLoader.new
      render :filters
    end
  end

  def destroy_blocked_company
    @blocked_company = BlockedCompany.find(params[:id])
    @blocked_company.destroy
    redirect_to settings_filters_path, notice: 'Company unblocked successfully'
  end

  private

  def blocked_company_params
    params.expect(blocked_company: %i[name pattern reason])
  end
end
