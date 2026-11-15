module NodeDB
  module SQL
    # SQL helpers for NodeDB timeseries engine.
    module Timeseries
      # Every interval form NodeDB accepts ("5m", "1 minute",
      # "2 hours 30 minutes", "500") uses only these characters. Rejecting
      # anything else keeps the value from leaving its quoted literal.
      INTERVAL_RE = /\A[0-9A-Za-z ]*[0-9A-Za-z][0-9A-Za-z ]*\z/
      ALIAS_RE = /\A[A-Za-z_][A-Za-z0-9_]*\z/

      # Returns a time_bucket() SQL fragment for use in SELECT.
      # Assumes the TIME_KEY column is named `timestamp` — NodeDB's own default
      # and what `Collection.create` declares. Older builds renamed any TIME_KEY
      # column to `timestamp` on projection; current builds honour the declared
      # name verbatim, so a collection with a differently-named TIME_KEY needs
      # its own clauses.
      def self.time_bucket(interval, as: :bucket)
        interval = interval.to_s
        unless INTERVAL_RE.match?(interval)
          raise ArgumentError,
            "time_bucket interval #{interval.inspect} must contain only digits, letters and spaces, e.g. \"5m\" or \"1 hour\""
        end
        unless ALIAS_RE.match?(as.to_s)
          raise ArgumentError, "time_bucket as: #{as.inspect} must be a bare identifier"
        end

        "time_bucket('#{interval}', timestamp) AS #{as}"
      end

      # Converts a Time (or anything responding to #to_r or #to_i) to Unix
      # milliseconds, keeping fractional seconds where #to_r exists. NodeDB
      # compares a TIME_KEY against epoch-ms integers, whether the column is
      # declared TIMESTAMP or BIGINT.
      def self.epoch_ms(time)
        time.respond_to?(:to_r) ? (time.to_r * 1000).floor : time.to_i * 1000
      end

      # Returns a WHERE fragment: timestamp > epoch_ms(time).
      # Uses literal interpolation — safe because epoch_ms always returns Integer.
      def self.since_clause(time)
        "timestamp > #{epoch_ms(time)}"
      end

      # Returns a WHERE fragment: timestamp <= epoch_ms(time).
      def self.until_clause(time)
        "timestamp <= #{epoch_ms(time)}"
      end
    end
  end
end
