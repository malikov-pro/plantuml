require File.expand_path('../../test_helper', __FILE__)

class PlantumlMacroTest < ActionController::TestCase
  include ApplicationHelper
  include ActionView::Helpers::AssetTagHelper
  include ERB::Util

  def setup
    Setting.plugin_plantuml['plantuml_server_url'] = 'http://localhost:8005'
    Setting.plugin_plantuml['allow_includes'] = false
  end

  def test_plantuml_macro_with_png
    text = <<-RAW
{{plantuml(png)
Bob -> Alice : hello
}}
RAW
    result = textilizable(text)
    assert_include 'http://localhost:8005/png/', result
    assert_include '<img', result
  end

  def test_plantuml_macro_with_svg
    text = <<-RAW
{{plantuml(svg)
Bob -> Alice : hello
}}
RAW
    result = textilizable(text)
    assert_include 'http://localhost:8005/svg/', result
    assert_include '<img', result
  end

  def test_plantuml_helper_url_generation
    url = PlantumlHelper.generate_plantuml_url('A -> B', 'png')
    assert_equal 'http://localhost:8005/png/SoWkIImgAStDuN9KqBLJSE9oICrB0N81', url
  end

  def test_plantuml_helper_sanitization
    Setting.plugin_plantuml['allow_includes'] = false
    sanitized = PlantumlHelper.sanitize_plantuml("A -> B\n!include something")
    assert_equal "A -> B\n", sanitized
  end

  def test_plantuml_helper_encoding
    encoded = PlantumlHelper.encode_plantuml("@startuml\nA -> B\n@enduml")
    assert_equal 'SoWkIImgAStDuN9KqBLJSE9oICrB0N81', encoded
  end

end
