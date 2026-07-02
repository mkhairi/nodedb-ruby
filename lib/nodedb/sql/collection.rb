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
      #
      # NodeDB's two engine spellings resolve through different upstream
      # code paths and each is broken for a different case:
      # - `WITH (engine='...')` + the BITEMPORAL flag builds a broken
      #   bitemporal schema (internal `__system_from_ms`/`__valid_*`
      #   columns leak into plain SELECT; `AS OF SYSTEM TIME NULL`
      #   projects only `_ts_system`).
      # - `ENGINE = timeseries` does not actually apply the engine (the
      #   collection behaves like a document engine: second INSERT hits a
      #   duplicate-empty-PK violation).
      # So: BITEMPORAL collections get the `ENGINE =` suffix (clean for
      # document_strict); everything else keeps the `WITH (engine=...)`
      # form. Collapse to one spelling when upstream unifies them.
      #
      # `flags` is an Array of free-standing modifier keywords appended to the
      # column-list parens. NodeDB v0.3.0 recognises `BITEMPORAL`,
      # `APPEND_ONLY`, and `HASH_CHAIN`.
      #
      #   Collection.create(:orders, engine: :document_strict,
      #     columns: ["id TEXT PRIMARY KEY", "total NUMERIC"],
      #     flags:   [:bitemporal])
      #   # => "CREATE COLLECTION orders (id TEXT PRIMARY KEY, total NUMERIC, BITEMPORAL) ENGINE = document_strict"
      def self.create(name, engine: nil, columns: [], engine_options: {}, flags: [])
        col_parts = columns.dup

        if col_parts.empty?
          case engine&.to_sym
          when :timeseries then col_parts = ["ts TIMESTAMP TIME_KEY", "value FLOAT"]
          when :kv         then col_parts = ["key TEXT PRIMARY KEY", "value TEXT"]
          end
        end

        flag_parts = Array(flags).map { |f| f.to_s.upcase }
        body_parts = col_parts + flag_parts

        bitemporal = flag_parts.include?("BITEMPORAL")
        opts = engine_options.to_h

        sql = +"CREATE COLLECTION #{name}"
        sql << " (#{body_parts.join(", ")})" if body_parts.any?
        if bitemporal
          engine_clause = build_engine_clause(engine)
          sql << " #{engine_clause}" if engine_clause
          sql << " WITH (#{opts.map { |k, v| "#{k}='#{v}'" }.join(', ')})" if opts.any?
        else
          with_clause = build_with_clause(engine, opts)
          sql << " #{with_clause}" if with_clause
        end
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

      def self.build_engine_clause(engine)
        effective = effective_engine(engine)
        return nil unless effective

        "ENGINE = #{effective}"
      end
      private_class_method :build_engine_clause

      def self.build_with_clause(engine, opts)
        effective = effective_engine(engine)
        return nil if effective.nil? && opts.empty?

        pairs = []
        pairs << "engine='#{effective}'" if effective
        opts.each { |k, v| pairs << "#{k}='#{v}'" }
        "WITH (#{pairs.join(', ')})"
      end
      private_class_method :build_with_clause

      # NodeDB removed the standalone `fts` engine: full-text search now
      # lives on a document_strict collection plus a separate
      # CREATE FULLTEXT INDEX. Map `engine: :fts` to document_strict so
      # legacy callers/migrations keep working. `:document`/nil need no
      # engine clause at all.
      def self.effective_engine(engine)
        engine_sym = engine&.to_sym
        return nil if engine_sym.nil? || engine_sym == :document

        engine_sym == :fts ? :document_strict : engine_sym
      end
      private_class_method :effective_engine
    end
  end
end
