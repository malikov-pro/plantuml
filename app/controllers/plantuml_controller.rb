require 'net/http'
require 'uri'

class PlantumlController < ApplicationController
  # unloadable больше не нужен в современных версиях Redmine

  def health_check
    server_url = Setting.plugin_plantuml['plantuml_server_url'] rescue nil
    
    if server_url.blank? || server_url.to_s.strip.empty?
      render json: { status: 'error', message: 'PlantUML server URL not configured' }, status: 500
      return
    end

    begin
      uri = URI.parse(server_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = 5
      http.read_timeout = 5
      
      response = http.get('/')
      
      if response.code.to_i == 200
        render json: { status: 'ok', message: 'PlantUML server is accessible', server_url: server_url }
      else
        render json: { status: 'error', message: "PlantUML server returned #{response.code}" }, status: 502
      end
    rescue => e
      render json: { status: 'error', message: "Cannot connect to PlantUML server: #{e.message}" }, status: 502
    end
  end
end
