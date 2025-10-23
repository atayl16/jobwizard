class FiltersController < ApplicationController
  def block_company
    company_name = params[:company_name]

    if company_name.present?
      BlockedCompany.create!(
        name: company_name,
        pattern: false,
        reason: 'manual'
      )

      redirect_to jobs_path, notice: "Company '#{company_name}' blocked successfully"
    else
      redirect_to jobs_path, alert: 'Company name is required'
    end
  end
end
