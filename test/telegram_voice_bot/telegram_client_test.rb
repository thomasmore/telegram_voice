# frozen_string_literal: true

require "minitest/autorun"
require "telegram_voice_bot"

module TelegramVoiceBot
  class TelegramClientTest < Minitest::Test
    def test_download_file_fetches_file_info_and_body
      client = TelegramClient.new(token: "token", logger: nil)

      class << client
        def perform(uri, _request, read_timeout: 60)
          case uri.to_s
          when /getFile/
            success_response(%({"ok":true,"result":{"file_path":"voice/file.ogg"}}))
          when %r{/file/bot}
            success_response("OggSfake")
          else
            raise "Unexpected URI: #{uri}"
          end
        end

        private

        def success_response(body)
          Struct.new(:body) do
            def is_a?(klass)
              klass == Net::HTTPSuccess || super
            end
          end.new(body)
        end
      end

      downloaded = client.download_file(file_id: "abc123")

      assert_equal "OggSfake", downloaded.body
      assert_equal "voice/file.ogg", downloaded.file_path
      assert_equal "audio/ogg", downloaded.content_type
    end
  end
end
