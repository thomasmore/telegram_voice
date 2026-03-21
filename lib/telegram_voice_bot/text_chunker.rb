# frozen_string_literal: true

module TelegramVoiceBot
  class TextChunker
    class << self
      def split(text, max_chars:)
        normalized = text.to_s.gsub(/\s+/, " ").strip
        return [] if normalized.empty?
        return [normalized] if normalized.length <= max_chars

        parts = []
        remaining = normalized

        until remaining.empty?
          if remaining.length <= max_chars
            parts << remaining
            break
          end

          slice = remaining[0, max_chars]
          breakpoint = breakpoint_for(slice) || max_chars
          part = remaining[0, breakpoint].strip
          part = remaining[0, max_chars].strip if part.empty?

          parts << part
          remaining = remaining[part.length..].to_s.strip
        end

        parts
      end

      private

      def breakpoint_for(text)
        [
          /[.!?]\s+/,
          /[,;:]\s+/,
          /\s+/
        ].each do |pattern|
          matches = text.to_enum(:scan, pattern).map { Regexp.last_match }
          return matches.last.end(0) if matches.any?
        end

        nil
      end
    end
  end
end

