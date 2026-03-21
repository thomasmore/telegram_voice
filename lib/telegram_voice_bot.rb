# frozen_string_literal: true

require "json"
require "logger"
require "net/http"
require "securerandom"
require "tempfile"
require "uri"

require_relative "telegram_voice_bot/env_loader"
require_relative "telegram_voice_bot/config"
require_relative "telegram_voice_bot/text_chunker"
require_relative "telegram_voice_bot/telegram_client"
require_relative "telegram_voice_bot/deepgram_client"
require_relative "telegram_voice_bot/bot"

