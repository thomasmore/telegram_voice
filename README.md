# Telegram Voice Bot on Ruby

This bot uses Telegram long polling plus Deepgram APIs to do two things:

- Any incoming voice message, including a forwarded voice message, is transcribed to text.
- Any incoming text message is converted into a Telegram voice note and sent back.

It runs as a plain Ruby process, which makes VPS deployment simple: no webhook, reverse proxy, or public HTTPS endpoint is required.

## What is included

- `bin/bot` - executable entrypoint
- `lib/telegram_voice_bot` - bot logic, Telegram client, Deepgram client, config, and helpers
- `systemd/telegram-voice-bot.service` - example unit for running the bot on a VPS

## Requirements

- Ruby 3.1+
- A Telegram bot token from `@BotFather`
- A Deepgram API key

## Configuration

Copy the example env file and fill in your credentials:

```bash
cp .env.example .env
```

Required variables:

- `TELEGRAM_BOT_TOKEN`
- `DEEPGRAM_API_KEY`

Useful optional variables:

- `DEEPGRAM_STT_MODEL` defaults to `nova-3`
- `DEEPGRAM_TTS_MODEL` defaults to `aura-2-thalia-en`
- `DEEPGRAM_DETECT_LANGUAGE` defaults to `true`
- `DEEPGRAM_LANGUAGE` forces transcription to a specific language if you do not want auto-detection
- `TTS_MAX_CHARS` controls how long one synthesized voice note can be before the bot splits it into multiple notes

## Run locally

```bash
ruby bin/bot
```

Then open the bot in Telegram and test:

1. Forward a voice message to the bot.
2. Send a plain text message to the bot.

## Deploy on a VPS

### 1. Install Ruby

On Ubuntu/Debian, for example:

```bash
sudo apt update
sudo apt install -y ruby-full
```

### 2. Put the project on the server

Example:

```bash
git clone <your-repo-url> /opt/telegram-voice
cd /opt/telegram-voice
cp .env.example .env
```

Fill in `.env`.

### 3. Install the systemd unit

Copy and edit the service file so `WorkingDirectory`, `ExecStart`, `User`, and `Group` match your real server setup:

```bash
sudo cp systemd/telegram-voice-bot.service /etc/systemd/system/telegram-voice-bot.service
sudo systemctl daemon-reload
sudo systemctl enable --now telegram-voice-bot
```

Check logs:

```bash
sudo journalctl -u telegram-voice-bot -f
```

## Deepgram notes

For speech-to-text, this bot posts Telegram voice audio to Deepgram's prerecorded transcription endpoint.

For text-to-speech, it requests `encoding=opus&container=ogg` from Deepgram and uploads that file directly to Telegram as a voice note, so no `ffmpeg` conversion step is needed.

As of March 21, 2026, Deepgram's public TTS voices documentation lists English, Spanish, German, French, Dutch, Italian, and Japanese Aura voices. If you need Russian voice output, this code will still work technically with any Deepgram model name you provide, but Deepgram's official docs did not list Russian TTS voices on that date.

Useful docs:

- https://developers.deepgram.com/docs/language
- https://developers.deepgram.com/docs/language-detection
- https://developers.deepgram.com/docs/tts-models
- https://developers.deepgram.com/docs/tts-encoding
- https://developers.deepgram.com/docs/tts-media-output-settings

## Behavior

- `/start` and `/help` return usage instructions.
- Unsupported messages get a short help reply.
- Long text is split into multiple synthesized voice notes so you do not hit provider or Telegram limits too quickly.
- Long transcripts are split into multiple Telegram text messages if needed.
