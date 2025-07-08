# PlantUML Redmine plugin

This plugin allows adding [PlantUML](http://plantuml.com/) diagrams into Redmine using a PlantUML server.

## Architecture

The plugin now works through HTTP requests to a PlantUML server instead of local binary execution:
- **No local PlantUML binary required**
- **No local file generation**
- **Direct URL generation** for PlantUML diagrams
- **NGINX caching support** for better performance

## Requirements

- **PlantUML Server** (Docker recommended)
- **Redmine 5.0+** (tested with 5.1.9, 6.0.6)

## Installation

### 1. Setup PlantUML Server

Using Docker (recommended):

```bash
docker run -d --name plantuml-server -p 8005:8080 plantuml/plantuml-server:tomcat
```

### 2. Install Plugin

Copy this plugin into the Redmine plugins directory:

```bash
cd redmine/plugins
git clone https://github.com/dkd/plantuml.git
```

### 3. Configure Plugin

- Go to **Administration** → **Plugins** → **PlantUML plugin** → **Configure**
- Set **PlantUML Server URL**: `http://localhost:8005`
- Configure **Allow includes** (security setting)
- Choose **Encoding**: `deflate` (recommended)

### 4. Optional: NGINX Caching

For better performance, configure NGINX proxy with caching:

```nginx
location /-/plantuml/ {
    rewrite ^/-/plantuml/(.*) /$1 break;
    proxy_pass http://localhost:8005;
    proxy_cache plantuml_cache;
    proxy_cache_valid 200 24h;
    proxy_cache_key "$request_uri";
    add_header X-Cache-Status $upstream_cache_status;
}
```

## Usage

PlantUML diagrams can be added using the same syntax:

### PNG Format
```
{{plantuml(png)
Bob -> Alice : hello
Alice -> Bob : hi there!
}}
```

### SVG Format  
```
{{plantuml(svg)
@startuml
participant Bob
participant Alice
Bob -> Alice : hello
Alice -> Bob : hi there!
@enduml
}}
```

## Security

### !include Directives

By default, `!include` directives are sanitized for security. You can enable them by:
- Setting **Allow includes** to `true` in plugin configuration
- **Warning**: This allows access to server files - use only in trusted environments

### Server Isolation

The PlantUML server should be isolated and not have access to sensitive files.

## Features

### Health Check

Check PlantUML server status: `GET /plantuml/health_check`

### URL Generation

Diagrams are rendered via direct URLs:
- Format: `{server_url}/{format}/{encoded_diagram}`
- Encoding: deflate + PlantUML base64
- Example: `http://localhost:8005/png/SoWkIImgAStDuN9KqBLJSE9oICrB0N81`

## Troubleshooting

### Server Connection Issues

1. **Check server status**: `curl http://localhost:8005/`
2. **Verify plugin configuration** in Redmine admin
3. **Check health endpoint**: `/plantuml/health_check`

### Diagram Not Rendering

1. **Verify PlantUML syntax** in external tool
2. **Check server logs** for errors
3. **Test with simple diagram** (e.g., `A -> B`)

### NGINX Issues

1. **Test without NGINX** first
2. **Check NGINX error logs**
3. **Verify proxy configuration**

## Migration from v0.5.x

The plugin now requires:
1. **Remove old settings**: `plantuml_binary_default`
2. **Add new setting**: `plantuml_server_url`  
3. **Setup PlantUML server** (Docker or standalone)
4. **Update NGINX config** (optional)

Old diagram syntax remains **100% compatible**.

## Compatibility

- **Redmine**: 5.0.x, 5.1.x, 6.0.x
- **Ruby**: 3.0+, 3.1+
- **Rails**: 6.1+, 7.0+

## Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality  
4. Submit pull request

## License

Same as original project license.
