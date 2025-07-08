# Окружение разработки для Redmine PlantUML плагина

## Системные требования

### Операционная система:
- Ubuntu 20.04 LTS или новее
- Минимум 4GB RAM
- 20GB свободного места на диске

### Необходимые компоненты:
- Ruby 3.0+ или 3.1+
- Rails 6.1+ или 7.0+
- PostgreSQL или MySQL
- Docker и Docker Compose
- NGINX
- Git
- Node.js (для assets)

## Пошаговая настройка окружения

### Шаг 1: Обновление системы

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl wget git build-essential
```

### Шаг 2: Установка Ruby через rbenv

```bash
# Установка rbenv
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

# Добавление в .bashrc
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Установка Ruby 3.1.0 (совместимость с Redmine 5.x-6.x)
rbenv install 3.1.0
rbenv global 3.1.0

# Проверка установки
ruby -v
gem -v
```

### Шаг 3: Установка Node.js и Yarn

```bash
# Установка Node.js 18.x LTS
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Установка Yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update
sudo apt install -y yarn

# Проверка
node -v
npm -v
yarn -v
```

### Шаг 4: Установка базы данных PostgreSQL

```bash
# Установка PostgreSQL
sudo apt install -y postgresql postgresql-contrib libpq-dev

# Запуск сервиса
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Создание пользователя для разработки
sudo -u postgres createuser -s $USER
sudo -u postgres createdb ${USER}_development
sudo -u postgres createdb ${USER}_test

# Установка пароля (опционально)
sudo -u postgres psql -c "ALTER USER $USER PASSWORD 'password';"
```

### Шаг 5: Установка Docker для PlantUML сервера

```bash
# Установка Docker
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER
newgrp docker

# Проверка
docker --version
docker compose version
```

### Шаг 6: Запуск PlantUML сервера

```bash
# Создание рабочей директории
mkdir -p ~/redmine-plantuml-dev
cd ~/redmine-plantuml-dev

# Создание docker-compose.yml для PlantUML
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  plantuml:
    image: plantuml/plantuml-server:tomcat
    container_name: plantuml-server
    ports:
      - "8005:8080"
    environment:
      - PLANTUML_LIMIT_SIZE=4096
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

# Запуск PlantUML сервера
docker compose up -d

# Проверка работы
curl http://localhost:8005/
```

### Шаг 7: Установка NGINX

```bash
# Установка NGINX
sudo apt install -y nginx

# Создание конфигурации для разработки
sudo tee /etc/nginx/sites-available/redmine-dev << 'EOF'
upstream redmine {
    server 127.0.0.1:3000;
}

proxy_cache_path /var/cache/nginx/plantuml levels=1:2 keys_zone=plantuml_cache:10m max_size=1g inactive=24h use_temp_path=off;

server {
    listen 80;
    server_name localhost redmine.local;

    # PlantUML прокси с кэшированием
    location /-/plantuml/ {
        rewrite ^/-/plantuml/(.*) /$1 break;
        proxy_pass http://127.0.0.1:8005;
        proxy_cache plantuml_cache;
        proxy_cache_valid 200 24h;
        proxy_cache_key "$request_uri";
        add_header X-Cache-Status $upstream_cache_status;
        
        # CORS заголовки для разработки
        add_header Access-Control-Allow-Origin "*";
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
        add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range";
    }

    # Redmine приложение
    location / {
        proxy_pass http://redmine;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Создание директории для кэша
sudo mkdir -p /var/cache/nginx/plantuml
sudo chown -R www-data:www-data /var/cache/nginx/plantuml

# Активация конфигурации
sudo ln -sf /etc/nginx/sites-available/redmine-dev /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### Шаг 8: Установка Redmine для разработки

```bash
# Клонирование Redmine (последняя стабильная версия)
cd ~/redmine-plantuml-dev
git clone https://github.com/redmine/redmine.git
cd redmine

# Переключение на стабильную ветку (например, 6.0-stable)
git checkout 6.0-stable

# Установка gem dependencies
gem install bundler
bundle install --without production

# Создание конфигурации базы данных
cp config/database.yml.example config/database.yml

# Редактирование database.yml для PostgreSQL
cat > config/database.yml << 'EOF'
development:
  adapter: postgresql
  database: redmine_development
  host: localhost
  username: postgres
  password: password
  encoding: utf8

test:
  adapter: postgresql
  database: redmine_test
  host: localhost
  username: postgres
  password: password
  encoding: utf8
EOF

# Создание секретного ключа
bundle exec rake generate_secret_token

# Создание базы данных и миграции
RAILS_ENV=development bundle exec rake db:create
RAILS_ENV=development bundle exec rake db:migrate
RAILS_ENV=development bundle exec rake redmine:load_default_data

# Создание тестовой базы
RAILS_ENV=test bundle exec rake db:create
RAILS_ENV=test bundle exec rake db:migrate
```

### Шаг 9: Установка существующего PlantUML плагина

```bash
# Переход в директорию плагинов
cd ~/redmine-plantuml-dev/redmine/plugins

# Клонирование PlantUML плагина
git clone https://github.com/dkd/plantuml.git

# Возврат в корень Redmine
cd ..

# Миграция плагина
RAILS_ENV=development bundle exec rake redmine:plugins:migrate
RAILS_ENV=test bundle exec rake redmine:plugins:migrate
```

### Шаг 10: Настройка инструментов разработки

```bash
# Установка дополнительных gems для разработки
cat >> Gemfile.local << 'EOF'
group :development, :test do
  gem 'pry'
  gem 'pry-rails'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'rubocop'
  gem 'rubocop-rails'
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'webmock'
  gem 'vcr'
end
EOF

# Установка gems
bundle install

# Настройка RuboCop
cat > .rubocop.yml << 'EOF'
require:
  - rubocop-rails

AllCops:
  TargetRubyVersion: 3.1
  NewCops: enable
  Exclude:
    - 'vendor/**/*'
    - 'tmp/**/*'
    - 'db/**/*'
    - 'config/**/*'
    - 'bin/**/*'

Metrics/LineLength:
  Max: 140

Style/Documentation:
  Enabled: false

Metrics/MethodLength:
  Max: 20

Metrics/ClassLength:
  Max: 200
EOF
```

### Шаг 11: Настройка VS Code (опционально)

```bash
# Установка VS Code
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt update
sudo apt install -y code

# Создание workspace настроек
mkdir -p .vscode
cat > .vscode/settings.json << 'EOF'
{
    "ruby.intellisense": "rubyLocate",
    "ruby.codeCompletion": "rcodetools",
    "ruby.format": "rubocop",
    "files.associations": {
        "*.erb": "erb"
    },
    "emmet.includeLanguages": {
        "erb": "html"
    }
}
EOF

cat > .vscode/extensions.json << 'EOF'
{
    "recommendations": [
        "rebornix.ruby",
        "wingrunr21.vscode-ruby",
        "bradlc.vscode-tailwindcss",
        "ms-vscode.vscode-json",
        "redhat.vscode-yaml"
    ]
}
EOF
```

## Запуск окружения разработки

### Ежедневный запуск:

```bash
# 1. Запуск PlantUML сервера (если не запущен)
cd ~/redmine-plantuml-dev
docker compose up -d

# 2. Запуск PostgreSQL (если не запущен)
sudo systemctl start postgresql

# 3. Запуск NGINX (если не запущен)
sudo systemctl start nginx

# 4. Запуск Redmine
cd ~/redmine-plantuml-dev/redmine
bundle exec rails server -b 0.0.0.0 -p 3000
```

### Проверка работы:

```bash
# Проверка PlantUML сервера
curl http://localhost:8005/

# Проверка NGINX прокси
curl http://localhost/-/plantuml/

# Проверка Redmine
curl http://localhost/
```

## Полезные команды для разработки

### Тестирование плагина:

```bash
# Unit тесты
RAILS_ENV=test bundle exec rake test:plugins:plantuml

# Все тесты Redmine
RAILS_ENV=test bundle exec rake test

# RuboCop проверка
bundle exec rubocop plugins/plantuml/
```

### Работа с базой данных:

```bash
# Сброс базы разработки
RAILS_ENV=development bundle exec rake db:drop db:create db:migrate redmine:load_default_data

# Миграция плагинов
RAILS_ENV=development bundle exec rake redmine:plugins:migrate
```

### Отладка:

```bash
# Rails консоль
bundle exec rails console

# Просмотр логов
tail -f log/development.log

# Просмотр NGINX логов
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## Структура проекта разработки

```
~/redmine-plantuml-dev/
├── docker-compose.yml          # PlantUML сервер
├── redmine/                    # Redmine код
│   ├── plugins/
│   │   └── plantuml/          # Плагин для разработки
│   ├── config/
│   ├── app/
│   └── ...
└── backup/                     # Бэкапы и тестовые данные
```

## Troubleshooting

### PlantUML сервер недоступен:
```bash
docker compose logs plantuml
docker compose restart plantuml
```

### NGINX ошибки:
```bash
sudo nginx -t
sudo systemctl status nginx
sudo journalctl -u nginx
```

### Проблемы с Ruby gems:
```bash
bundle clean --force
bundle install
```

### Проблемы с базой данных:
```bash
sudo systemctl status postgresql
sudo -u postgres psql -l
```

Это окружение обеспечит все необходимое для комфортной разработки и тестирования PlantUML плагина для Redmine. 