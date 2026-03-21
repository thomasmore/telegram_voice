# frozen_string_literal: true

module TelegramVoiceBot
  class Bot
    TRANSCRIPT_MESSAGE_LIMIT = 3500

    def initialize(config:, logger:)
      @config = config
      @logger = logger
      @telegram = TelegramClient.new(token: config.telegram_bot_token, logger: logger)
      @deepgram = DeepgramClient.new(config: config, logger: logger)
    end

    def run
      @logger.info("Starting Telegram voice bot")
      offset = nil

      loop do
        updates = @telegram.poll_updates(
          offset: offset,
          timeout: @config.telegram_poll_timeout,
          limit: @config.telegram_poll_limit
        )

        updates.each do |update|
          offset = update.fetch("update_id") + 1
          process_update(update)
        end
      rescue StandardError => e
        @logger.error("Polling loop failed: #{e.class}: #{e.message}")
        sleep 5
      end
    end

    private

    def process_update(update)
      message = update["message"]
      return unless message
      return if message.dig("from", "is_bot")

      if message["voice"]
        handle_voice_message(message)
      elsif message["text"]
        handle_text_message(message)
      else
        send_help(message)
      end
    rescue StandardError => e
      @logger.error("Failed to process update #{update['update_id']}: #{e.class}: #{e.message}")
      chat_id = message&.dig("chat", "id")
      return unless chat_id

      @telegram.send_message(
        chat_id: chat_id,
        text: "I could not process that message. Check the bot logs and try again.",
        reply_to_message_id: message["message_id"]
      )
    end

    def handle_voice_message(message)
      chat_id = message.dig("chat", "id")
      voice = message.fetch("voice")

      @telegram.send_chat_action(chat_id: chat_id, action: "typing")

      downloaded = @telegram.download_file(file_id: voice.fetch("file_id"))
      transcript = @deepgram.transcribe(
        audio_bytes: downloaded.body,
        content_type: voice["mime_type"] || downloaded.content_type
      )

      if transcript.empty?
        @telegram.send_message(
          chat_id: chat_id,
          text: "I could not detect speech in that voice message.",
          reply_to_message_id: message["message_id"]
        )
        return
      end

      TextChunker.split(transcript, max_chars: TRANSCRIPT_MESSAGE_LIMIT).each do |chunk|
        @telegram.send_message(
          chat_id: chat_id,
          text: chunk,
          reply_to_message_id: message["message_id"]
        )
      end
    end

    def handle_text_message(message)
      text = message["text"].to_s.strip
      return send_help(message) if text.empty?
      return send_help(message) if help_command?(text)

      chat_id = message.dig("chat", "id")
      chunks = TextChunker.split(text, max_chars: @config.tts_max_chars)

      chunks.each_with_index do |chunk, index|
        @telegram.send_chat_action(chat_id: chat_id, action: "upload_voice")
        audio = @deepgram.synthesize(text: chunk)

        Tempfile.create(["telegram-voice-bot-", ".ogg"]) do |file|
          file.binmode
          file.write(audio)
          file.flush

          @telegram.send_voice(
            chat_id: chat_id,
            file_path: file.path,
            filename: voice_filename(index),
            content_type: "audio/ogg",
            reply_to_message_id: index.zero? ? message["message_id"] : nil,
            caption: caption_for(index, chunks.length)
          )
        end
      end
    end

    def send_help(message)
      @telegram.send_message(
        chat_id: message.dig("chat", "id"),
        text: help_text,
        reply_to_message_id: message["message_id"]
      )
    end

    def help_command?(text)
      command = text.split(/\s+/, 2).first
      ["/start", "/help"].include?(command.to_s.split("@", 2).first)
    end

    def help_text
      <<~TEXT.strip
        Send me a voice message and I will transcribe it to text.
        Send me plain text and I will turn it into a Telegram voice note.
      TEXT
    end

    def caption_for(index, total)
      return nil if total <= 1

      "Part #{index + 1}/#{total}"
    end

    def voice_filename(index)
      "reply-#{index + 1}.ogg"
    end
  end
end

