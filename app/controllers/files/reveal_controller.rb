# frozen_string_literal: true

module Files
  class RevealController < ApplicationController
    # Dev-only controller to reveal files in Finder/Explorer

    # POST /files/reveal
    def create
      unless Rails.env.development?
        head :forbidden
        return
      end

      path = params[:path]

      if path.blank?
        redirect_back fallback_location: root_path, alert: 'No path provided'
        return
      end

      # Security: Only allow paths under output root
      output_root = JobWizard::OUTPUT_ROOT.to_s
      expanded_path = File.expand_path(path)

      unless expanded_path.start_with?(output_root)
        redirect_back fallback_location: root_path, alert: 'Invalid path'
        return
      end

      # Check if path exists
      unless File.exist?(expanded_path)
        redirect_back fallback_location: root_path, alert: 'Path does not exist'
        return
      end

      # Open in Finder (macOS) or Explorer (Windows)
      if RUBY_PLATFORM.include?('darwin')
        system('open', expanded_path)
      elsif RUBY_PLATFORM.include?('linux')
        system('xdg-open', expanded_path)
      elsif RUBY_PLATFORM.include?('win')
        system('explorer', expanded_path)
      end

      redirect_back fallback_location: root_path, notice: 'Opened in file manager'
    end
  end
end
