# frozen_string_literal: true

module TelegramVoiceBot
  class EnvLoader
    class << self
      def load!(path)
        return unless File.file?(path)

        File.readlines(path, chomp: true).each do |line|
          next if ignored_line?(line)

          key, raw_value = parse_assignment(line)
          next unless key && raw_value

          ENV[key] ||= normalize_value(raw_value)
        end
      end

      private

      def ignored_line?(line)
        stripped = line.strip
        stripped.empty? || stripped.start_with?("#")
      end

      def parse_assignment(line)
        normalized = line.sub(/\Aexport\s+/, "")
        normalized.split("=", 2)
      end

      def normalize_value(value)
        stripped = value.strip
        return "" if stripped.empty?

        if quoted?(stripped)
          unescape(stripped[1..-2], stripped[0])
        else
          stripped
        end
      end

      def quoted?(value)
        (value.start_with?('"') && value.end_with?('"')) ||
          (value.start_with?("'") && value.end_with?("'"))
      end

      def unescape(value, quote)
        return value if quote == "'"

        value
          .gsub('\n', "\n")
          .gsub('\r', "\r")
          .gsub('\t', "\t")
          .gsub('\"', '"')
      end
    end
  end
end

