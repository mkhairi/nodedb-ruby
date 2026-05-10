module NodeDB
  module SQL
    # SQL helpers for NodeDB KV engine.
    module KV
      # Returns UPDATE ... SET ttl SQL for per-row TTL on KV collections.
      # table and key must be pre-quoted by the caller.
      def self.set_ttl(table:, key:, ttl:)
        "UPDATE #{table} SET ttl = #{ttl.to_i} WHERE key = #{key}"
      end
    end
  end
end
