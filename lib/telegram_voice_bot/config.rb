# frozen_string_literal: true

module TelegramVoiceBot
  Config = Struct.new(
    :telegram_bot_token,
    :deepgram_api_key,
    :deepgram_stt_model,
    :deepgram_tts_model,
    :deepgram_language,
    :deepgram_detect_language,
    :telegram_poll_timeout,
    :telegram_poll_limit,
    :tts_max_chars,
    keyword_init: true
  ) do
    class << self
      def from_env
        new(
          telegram_bot_token: fetch_required("TELEGRAM_BOT_TOKEN"),
          deepgram_api_key: fetch_required("DEEPGRAM_API_KEY"),
          deepgram_stt_model: ENV.fetch("DEEPGRAM_STT_MODEL", "nova-3"),
          deepgram_tts_model: ENV.fetch("DEEPGRAM_TTS_MODEL", "aura-2-thalia-en"),
          deepgram_language: optional_value("DEEPGRAM_LANGUAGE"),
          deepgram_detect_language: env_bool("DEEPGRAM_DETECT_LANGUAGE", default: true),
          telegram_poll_timeout: integer_env("TELEGRAM_POLL_TIMEOUT", default: 30),
          telegram_poll_limit: integer_env("TELEGRAM_POLL_LIMIT", default: 20),
          tts_max_chars: integer_env("TTS_MAX_CHARS", default: 1800)
        )
      end

      def logger_level_from_env
        Logger.const_get(ENV.fetch("LOG_LEVEL", "INFO").upcase)
      rescue NameError
        Logger::INFO
      end

      private

      def fetch_required(name)
        value = ENV[name].to_s.strip
        raise ArgumentError, "Missing required environment variable #{name}" if value.empty?

        value
      end

      def optional_value(name)
        value = ENV[name].to_s.strip
        value.empty? ? nil : value
      end

      def env_bool(name, default:)
        raw = ENV[name]
        return default if raw.nil?

        %w[1 true yes on].include?(raw.strip.downcase)
      end

      def integer_env(name, default:)
        Integer(ENV.fetch(name, default.to_s))
      rescue ArgumentError
        default
      end
    end
  end
end

