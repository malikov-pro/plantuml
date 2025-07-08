Redmine::Plugin.register :plantuml do
  name 'PlantUML plugin for Redmine'
  author 'Michael Skrynski'
  description 'This is a plugin for Redmine which renders PlantUML diagrams.'
  version '1.0.0'
  url 'https://github.com/dkd/plantuml'

  requires_redmine version: '5.0'..'6.1'

  settings(partial: 'settings/plantuml',
           default: { 
             'plantuml_server_url' => 'http://localhost:8005',
             'allow_includes' => false,
             'encoding' => 'deflate'
           })

  Redmine::WikiFormatting::Macros.register do
    desc <<EOF
      Render PlantUML image.
      <pre>
      {{plantuml(png)
      (Bob -> Alice : hello)
      }}
      </pre>

      Available options are:
      ** (png|svg)
EOF
    macro :plantuml do |obj, args, text|
      raise 'No PlantUML server URL set.' if Setting.plugin_plantuml['plantuml_server_url'].blank?
      raise 'No or bad arguments.' if args.size != 1
      frmt = PlantumlHelper.check_format(args.first)
      image_url = PlantumlHelper.generate_plantuml_url(text, args.first)
      image_tag image_url
    end
  end
end

Rails.configuration.to_prepare do
  # Guards against including the module multiple time (like in tests)
  # and registering multiple callbacks

  unless Redmine::WikiFormatting::Textile::Helper.included_modules.include? PlantumlHelperPatch
    Redmine::WikiFormatting::Textile::Helper.send(:include, PlantumlHelperPatch)
  end
end
