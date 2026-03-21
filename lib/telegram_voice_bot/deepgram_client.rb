# frozen_string_literal: true

module TelegramVoiceBot
  class DeepgramClient
    ApiError = Class.new(StandardError)

    API_BASE_URL = "https://api.deepgram.com".freeze
    MULTILINGUAL_LANGUAGE_MODELS = %w[nova-3 nova-3-general].freeze

    def initialize(config:, logger:)
      @api_key = config.deepgram_api_key
      @stt_model = config.deepgram_stt_model
      @tts_model = config.deepgram_tts_model
      @language = config.deepgram_language
      @detect_language = config.deepgram_detect_language
      @logger = logger
    end

    def transcribe(audio_bytes:, content_type:)
      effective_content_type = transcription_content_type(audio_bytes, content_type)
      uri = URI("#{API_BASE_URL}/v1/listen?#{URI.encode_www_form(transcription_params)}")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Token #{@api_key}"
      request["Content-Type"] = effective_content_type
      request.body = audio_bytes

      response = perform(uri, request, read_timeout: 120)
      payload = parse_json(response, "transcription")

      transcript = payload.dig("results", "channels", 0, "alternatives", 0, "transcript").to_s.strip
      log_empty_transcript(payload, effective_content_type) if transcript.empty?
      transcript
    end

    def synthesize(text:)
      uri = URI(
        "#{API_BASE_URL}/v1/speak?" \
        "#{URI.encode_www_form(model: @tts_model, encoding: "opus", container: "ogg")}"
      )
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Token #{@api_key}"
      request["Content-Type"] = "application/json"
      request["Accept"] = "audio/ogg;codecs=opus"
      request.body = JSON.generate(text: text)

      response = perform(uri, request, read_timeout: 120)
      return response.body if response.is_a?(Net::HTTPSuccess)

      raise ApiError, "Deepgram synthesis failed with HTTP #{response.code}: #{response.body}"
    end

    private

    def transcription_params
      params = {
        model: @stt_model,
        smart_format: "true"
      }

      if @language
        params[:language] = @language
      elsif multilingual_language_mode?
        params[:language] = "multi"
      elsif @detect_language
        params[:detect_language] = "true"
      end

      params
    end

    def perform(uri, request, read_timeout:)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.open_timeout = 10
        http.read_timeout = read_timeout
        http.request(request)
      end
    end

    def parse_json(response, action_name)
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

      raise ApiError, "Deepgram #{action_name} failed with HTTP #{response.code}: #{response.body}"
    rescue JSON::ParserError
      raise ApiError, "Deepgram #{action_name} returned a non-JSON response"
    end

    def transcription_content_type(audio_bytes, content_type)
      normalized = content_type.to_s.strip
      return "audio/ogg;codecs=opus" if ogg_container?(audio_bytes) && oggish_content_type?(normalized)

      normalized.empty? ? "application/octet-stream" : normalized
    end

    def ogg_container?(audio_bytes)
      audio_bytes.to_s.start_with?("OggS")
    end

    def oggish_content_type?(content_type)
      return true if content_type.empty?

      lower = content_type.downcase
      lower.start_with?("audio/ogg") || lower == "audio/opus" || lower == "application/octet-stream"
    end

    def log_empty_transcript(payload, content_type)
      alternative = payload.dig("results", "channels", 0, "alternatives", 0) || {}
      @logger.warn(
        "Deepgram returned an empty transcript " \
        "content_type=#{content_type.inspect} " \
        "request_id=#{payload.dig("metadata", "request_id").inspect} " \
        "duration=#{payload.dig("metadata", "duration").inspect} " \
        "detected_language=#{alternative["detected_language"].inspect} " \
        "language_confidence=#{alternative["language_confidence"].inspect} " \
        "confidence=#{alternative["confidence"].inspect} " \
        "words=#{Array(alternative["words"]).length}"
      )
    end

    def multilingual_language_mode?
      @detect_language && MULTILINGUAL_LANGUAGE_MODELS.include?(@stt_model)
    end
  end
end
