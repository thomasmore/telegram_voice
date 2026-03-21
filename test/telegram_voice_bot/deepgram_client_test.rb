# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "telegram_voice_bot"

module TelegramVoiceBot
  class DeepgramClientTest < Minitest::Test
    ConfigStub = Struct.new(
      :deepgram_api_key,
      :deepgram_stt_model,
      :deepgram_tts_model,
      :deepgram_language,
      :deepgram_detect_language,
      keyword_init: true
    )

    def test_transcribe_uses_ogg_opus_content_type_for_telegram_voice_bytes
      logger = Logger.new(StringIO.new)
      client = DeepgramClient.new(config: config_stub, logger: logger)

      captured_content_type = nil

      class << client
        attr_accessor :response_body
      end

      client.response_body = %({"results":{"channels":[{"alternatives":[{"transcript":"hello"}]}]}})

      client.define_singleton_method(:perform) do |_uri, request, read_timeout:|
        captured_content_type = request["Content-Type"]

        Struct.new(:body) do
          def is_a?(klass)
            klass == Net::HTTPSuccess || super
          end
        end.new(response_body)
      end

      transcript = client.transcribe(audio_bytes: "OggSvoice-data", content_type: "audio/ogg")

      assert_equal "hello", transcript
      assert_equal "audio/ogg;codecs=opus", captured_content_type
    end

    def test_transcribe_logs_details_when_transcript_is_empty
      output = StringIO.new
      logger = Logger.new(output)
      logger.level = Logger::WARN
      client = DeepgramClient.new(config: config_stub, logger: logger)

      class << client
        attr_accessor :response_body
      end

      client.response_body = %({
        "metadata":{"request_id":"req-1","duration":1.25},
        "results":{"channels":[{"alternatives":[{"transcript":"","detected_language":"ru","language_confidence":0.91,"confidence":0.12,"words":[]}]}]}
      })

      client.define_singleton_method(:perform) do |_uri, _request, read_timeout:|
        Struct.new(:body) do
          def is_a?(klass)
            klass == Net::HTTPSuccess || super
          end
        end.new(response_body)
      end

      transcript = client.transcribe(audio_bytes: "OggSvoice-data", content_type: "audio/ogg")

      assert_equal "", transcript
      assert_includes output.string, "Deepgram returned an empty transcript"
      assert_includes output.string, "request_id=\"req-1\""
      assert_includes output.string, "detected_language=\"ru\""
    end

    def test_transcription_params_use_multilingual_mode_for_nova_3
      client = DeepgramClient.new(config: config_stub, logger: Logger.new(StringIO.new))

      params = client.send(:transcription_params)

      assert_equal "nova-3", params[:model]
      assert_equal "multi", params[:language]
      refute_includes params.keys, :detect_language
    end

    def test_transcription_params_use_explicit_language_when_configured
      config = ConfigStub.new(
        deepgram_api_key: "key",
        deepgram_stt_model: "nova-3",
        deepgram_tts_model: "aura-2-thalia-en",
        deepgram_language: "ru",
        deepgram_detect_language: true
      )
      client = DeepgramClient.new(config: config, logger: Logger.new(StringIO.new))

      params = client.send(:transcription_params)

      assert_equal "ru", params[:language]
      refute_includes params.keys, :detect_language
    end

    private

    def config_stub
      ConfigStub.new(
        deepgram_api_key: "key",
        deepgram_stt_model: "nova-3",
        deepgram_tts_model: "aura-2-thalia-en",
        deepgram_language: nil,
        deepgram_detect_language: true
      )
    end
  end
end
