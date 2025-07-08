require 'zlib'

module PlantumlHelper
  ALLOWED_FORMATS = {
    'png' => { type: 'png', ext: '.png', content_type: 'image/png', inline: true },
    'svg' => { type: 'svg', ext: '.svg', content_type: 'image/svg+xml', inline: true }
  }.freeze

  def self.check_format(frmt)
    ALLOWED_FORMATS.fetch(frmt, ALLOWED_FORMATS['png'])
  end

  def self.generate_plantuml_url(text, format)
    frmt = check_format(format)
    server_url = Setting.plugin_plantuml['plantuml_server_url']
    
    # Подготовка PlantUML кода
    plantuml_code = "@startuml\n#{sanitize_plantuml(text)}\n@enduml"
    
    # Кодирование по стандарту PlantUML (deflate + специальная base64)
    encoded = encode_plantuml(plantuml_code)
    
    # Формирование URL
    "#{server_url.chomp('/')}/#{frmt[:type]}/#{encoded}"
  end

  def self.encode_plantuml(plantuml_text)
    # UTF-8 encoding
    utf8_data = plantuml_text.force_encoding('UTF-8').encode('UTF-8')
    
    # Raw deflate compression (без zlib заголовков)
    deflater = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS)
    compressed = deflater.deflate(utf8_data, Zlib::FINISH)
    deflater.close
    
    # PlantUML специальная base64 кодировка
    encode_plantuml_base64(compressed)
  end

  def self.encode_plantuml_base64(data)
    result = ""
    i = 0
    
    while i < data.length
      # Берем по 3 байта за раз
      if i + 2 < data.length
        b1 = data[i].ord
        b2 = data[i + 1].ord  
        b3 = data[i + 2].ord
        result += append_3_bytes(b1, b2, b3)
      elsif i + 1 < data.length
        b1 = data[i].ord
        b2 = data[i + 1].ord
        result += append_3_bytes(b1, b2, 0)
      else
        b1 = data[i].ord
        result += append_3_bytes(b1, 0, 0)
      end
      i += 3
    end
    
    result
  end

  def self.append_3_bytes(b1, b2, b3)
    c1 = b1 >> 2
    c2 = ((b1 & 0x3) << 4) | (b2 >> 4)
    c3 = ((b2 & 0xF) << 2) | (b3 >> 6)
    c4 = b3 & 0x3F
    
    encode_6_bit(c1) + encode_6_bit(c2) + encode_6_bit(c3) + encode_6_bit(c4)
  end

  def self.encode_6_bit(b)
    # PlantUML специальная таблица символов (НЕ стандартная base64!)
    if b < 10
      return (48 + b).chr  # 0-9
    end
    b -= 10
    if b < 26
      return (65 + b).chr  # A-Z
    end
    b -= 26
    if b < 26
      return (97 + b).chr  # a-z  
    end
    b -= 26
    if b == 0
      return '-'
    end
    if b == 1
      return '_'
    end
    return '?'
  end

  def self.sanitize_plantuml(text)
    return text if Setting.plugin_plantuml['allow_includes']
    text.gsub(/!include.*$/, '')
  end
end
