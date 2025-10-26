# frozen_string_literal: true

class ManualApplicationsController < ApplicationController
  before_action :set_application, only: %i[show edit update destroy]

  # GET /manual_applications
  def index
    @applications = ManualApplication.recent
    @status_counts = ManualApplication.group(:status).count
    @status_filter = params[:status]
    
    @applications = @applications.by_status(@status_filter) if @status_filter.present?
  end

  # GET /manual_applications/new
  def new
    @application = ManualApplication.new
  end

  # POST /manual_applications
  def create
    @application = ManualApplication.new(application_params)

    if @application.save
      redirect_to manual_applications_path, notice: 'Application added successfully'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /manual_applications/:id
  def show
  end

  # GET /manual_applications/:id/edit
  def edit
  end

  # PATCH /manual_applications/:id
  def update
    if @application.update(application_params)
      redirect_to @application, notice: 'Application updated successfully'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /manual_applications/:id
  def destroy
    @application.destroy
    redirect_to manual_applications_path, notice: 'Application removed successfully'
  end

  private

  def set_application
    @application = ManualApplication.find(params[:id])
  end

  def application_params
    params.require(:manual_application).permit(:company, :position, :applied_at, :status, :notes, :job_url)
  end
end
