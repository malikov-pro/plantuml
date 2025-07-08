require File.expand_path('../../test_helper', __FILE__)

class PlantumlControllerTest < ActionController::TestCase
  def setup
    @request.session[:user_id] = 1
    Setting.default_language = 'en'
    Setting.plugin_plantuml['plantuml_server_url'] = 'http://localhost:8005'
  end

  def test_health_check_route_exists
    # Простая проверка что роут существует
    assert_routing '/plantuml/health_check', controller: 'plantuml', action: 'health_check'
  end

  def test_health_check_no_server_url_configured
    # Удаляем настройку полностью
    Setting.plugin_plantuml = {}
    
    get :health_check
    assert_response 500
    
    response_data = JSON.parse(@response.body)
    assert_equal 'error', response_data['status']
    assert_include 'not configured', response_data['message']
  end

  def test_health_check_with_invalid_url
    Setting.plugin_plantuml['plantuml_server_url'] = 'invalid-url'
    
    get :health_check
    assert_response 502
    
    response_data = JSON.parse(@response.body)
    assert_equal 'error', response_data['status']
  end

end
