module NodeDB
  module SQL
    # SQL builders for NodeDB collection DDL.
    # All methods return plain SQL strings; quoting is the caller's responsibility.
    module Collection
      # Returns CREATE COLLECTION SQL.
      # columns: array of pre-formatted "name TYPE [constraints]" strings.
      # engine:  :timeseries | :kv | :columnar | :spatial | :fts | nil (document)
      def self.create(name, engine: nil, columns: [])
        col_parts = columns.dup

        if col_parts.empty?
          case engine&.to_sym
          when :timeseries then col_parts = ["ts TIMESTAMP TIME_KEY", "value FLOAT"]
          when :kv         then col_parts = ["key TEXT PRIMARY KEY", "value TEXT"]
          end
        end

        sql = +"CREATE COLLECTION #{name}"
        sql << " (#{col_parts.join(", ")})" if col_parts.any?
        sql << " #{engine_clause(engine)}" if engine && engine.to_sym != :document
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

      def self.engine_clause(engine)
        return nil if engine.nil? || engine.to_sym == :document
        "WITH (engine='#{engine}')"
      end
      private_class_method :engine_clause
    end
  end
end
