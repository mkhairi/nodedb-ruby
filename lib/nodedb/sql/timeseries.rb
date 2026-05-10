module NodeDB
  module SQL
    # SQL helpers for NodeDB timeseries engine.
    module Timeseries
      # Returns a time_bucket() SQL fragment for use in SELECT.
      # NodeDB timeseries renames the TIME_KEY column to `timestamp` internally.
      def self.time_bucket(interval, as: :bucket)
        "time_bucket('#{interval}', timestamp) AS #{as}"
      end

      # Converts a Ruby Time (or anything responding to #to_i) to Unix milliseconds.
      # NodeDB timeseries stores and filters on epoch-ms integers.
      def self.epoch_ms(time)
        time.to_i * 1000
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
