module NodeDB
  module SQL
    # SQL builders for NodeDB collection DDL.
    # All methods return plain SQL strings; quoting is the caller's responsibility.
    module Collection
      # Returns CREATE COLLECTION SQL.
      # columns:        array of pre-formatted "name TYPE [constraints]" strings.
      # engine:         :timeseries | :kv | :columnar | :spatial | :fts | nil (document)
      # engine_options: extra key/value pairs serialised into the WITH clause,
      #                 e.g. { retention: "30d", compression: "zstd" }
      #
      #   Collection.create(:metrics, engine: :timeseries,
      #     engine_options: { retention: "7d" })
      #   # => "CREATE COLLECTION metrics (...) WITH (engine='timeseries', retention='7d')"
      def self.create(name, engine: nil, columns: [], engine_options: {})
        col_parts = columns.dup

        if col_parts.empty?
          case engine&.to_sym
          when :timeseries then col_parts = ["ts TIMESTAMP TIME_KEY", "value FLOAT"]
          when :kv         then col_parts = ["key TEXT PRIMARY KEY", "value TEXT"]
          end
        end

        sql = +"CREATE COLLECTION #{name}"
        sql << " (#{col_parts.join(", ")})" if col_parts.any?
        with_clause = build_with_clause(engine, engine_options)
        sql << " #{with_clause}" if with_clause
        sql
      end

      def self.drop(name)
        "DROP COLLECTION #{name}"
      end

      def self.drop_if_exists(name)
        "DROP COLLECTION IF EXISTS #{name}"
      end

      def self.show
        "SHOW COLLECTIONS"
      end

      def self.describe(name)
        "DESCRIBE #{name}"
      end

      def self.build_with_clause(engine, engine_options)
        opts = engine_options.to_h
        engine_sym = engine&.to_sym
        return nil if (engine_sym.nil? || engine_sym == :document) && opts.empty?

        pairs = []
        pairs << "engine='#{engine}'" if engine_sym && engine_sym != :document
        opts.each { |k, v| pairs << "#{k}='#{v}'" }
        "WITH (#{pairs.join(', ')})"
      end
      private_class_method :build_with_clause
    end
  end
end
