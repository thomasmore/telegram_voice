# frozen_string_literal: true

module TelegramVoiceBot
  class TelegramClient
    ApiError = Class.new(StandardError)
    DownloadedFile = Struct.new(:body, :file_path, :content_type, keyword_init: true)

    API_BASE_URL = "https://api.telegram.org".freeze

    def initialize(token:, logger:)
      @token = token
      @logger = logger
    end

    def poll_updates(offset:, timeout:, limit:)
      params = {
        timeout: timeout,
        limit: limit
      }
      params[:offset] = offset if offset

      get_json("getUpdates", params, read_timeout: timeout + 10)
    end

    def send_message(chat_id:, text:, reply_to_message_id: nil)
      post_form(
        "sendMessage",
        compact_params(
          chat_id: chat_id,
          text: text,
          reply_to_message_id: reply_to_message_id,
          allow_sending_without_reply: true
        )
      )
    end

    def send_chat_action(chat_id:, action:)
      post_form("sendChatAction", chat_id: chat_id, action: action)
    end

    def download_file(file_id:)
      file_info = get_json("getFile", { file_id: file_id })
      file_path = file_info.fetch("file_path")

      uri = URI("#{API_BASE_URL}/file/bot#{@token}/#{file_path}")
      response = perform(uri, Net::HTTP::Get.new(uri))

      unless response.is_a?(Net::HTTPSuccess)
        raise ApiError, "Telegram file download failed with HTTP #{response.code}"
      end

      DownloadedFile.new(
        body: response.body,
        file_path: file_path,
        content_type: content_type_for(file_path)
      )
    end

    def send_voice(chat_id:, file_path:, filename:, content_type:, reply_to_message_id: nil, caption: nil)
      fields = compact_params(
        chat_id: chat_id,
        reply_to_message_id: reply_to_message_id,
        allow_sending_without_reply: true,
        caption: caption
      )

      post_multipart(
        "sendVoice",
        fields: fields,
        file_field: "voice",
        file_path: file_path,
        filename: filename,
        content_type: content_type
      )
    end

    private

    def get_json(method, params, read_timeout: 60)
      uri = api_uri(method, params)
      response = perform(uri, Net::HTTP::Get.new(uri), read_timeout: read_timeout)
      parse_api_response(response, method)
    end

    def post_form(method, params)
      uri = api_uri(method)
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(params.transform_values(&:to_s))
      response = perform(uri, request)
      parse_api_response(response, method)
    end

    def post_multipart(method, fields:, file_field:, file_path:, filename:, content_type:)
      uri = api_uri(method)
      boundary = "telegram_voice_bot_#{SecureRandom.hex(12)}"
      body = build_multipart_body(
        boundary: boundary,
        fields: fields,
        file_field: file_field,
        file_path: file_path,
        filename: filename,
        content_type: content_type
      )

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      request.body = body

      response = perform(uri, request)
      parse_api_response(response, method)
    end

    def perform(uri, request, read_timeout: 60)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.open_timeout = 10
        http.read_timeout = read_timeout
        http.request(request)
      end
    end

    def parse_api_response(response, method)
      payload = JSON.parse(response.body)
      return payload.fetch("result") if response.is_a?(Net::HTTPSuccess) && payload["ok"]

      description = payload["description"] || "unknown Telegram API error"
      raise ApiError, "Telegram #{method} failed: #{description}"
    rescue JSON::ParserError
      raise ApiError, "Telegram #{method} returned a non-JSON response"
    end

    def api_uri(method, params = nil)
      uri = URI("#{API_BASE_URL}/bot#{@token}/#{method}")
      uri.query = URI.encode_www_form(params) if params && !params.empty?
      uri
    end

    def compact_params(params)
      params.each_with_object({}) do |(key, value), result|
        result[key] = value unless value.nil?
      end
    end

    def build_multipart_body(boundary:, fields:, file_field:, file_path:, filename:, content_type:)
      body = String.new(capacity: 1024, encoding: Encoding::BINARY)

      fields.each do |key, value|
        body << "--#{boundary}\r\n".b
        body << %(Content-Disposition: form-data; name="#{key}"\r\n\r\n).b
        body << value.to_s.b
        body << "\r\n".b
      end

      body << "--#{boundary}\r\n".b
      body << %(Content-Disposition: form-data; name="#{file_field}"; filename="#{filename}"\r\n).b
      body << "Content-Type: #{content_type}\r\n\r\n".b
      body << File.binread(file_path)
      body << "\r\n--#{boundary}--\r\n".b
      body
    end

    def content_type_for(file_path)
      extension = File.extname(file_path).downcase

      case extension
      when ".ogg", ".oga", ".opus"
        "audio/ogg"
      when ".mp3"
        "audio/mpeg"
      when ".wav"
        "audio/wav"
      when ".m4a"
        "audio/mp4"
      else
        "application/octet-stream"
      end
    end
  end
end
