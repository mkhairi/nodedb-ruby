module NodeDB
  # Typed schema introspection over NodeDB's DESCRIBE / SHOW COLLECTIONS.
  #
  #   NodeDB::Schema.columns(conn, "articles")
  #   # => [#<Column name="id" type="TEXT" pg_type="text" oid=25
  #   #             nullable=false primary_key=true>, ...]
  #   NodeDB::Schema.collections(conn)  # => ["articles", ...]
  #
  # Normalizes the raw DESCRIBE quirks both adapters used to handle
  # separately: duplicate rows for the primary-key column (one carries
  # "PRIMARY KEY" in the type), and `__`-prefixed internal columns
  # (hidden unless `internal: true`).
  #
  # Works on either transport — pass anything that responds to
  # exec(sql) (PG::Connection) or run(sql) (Native::Connection).
  module Schema
    Column = Data.define(:name, :type, :pg_type, :oid, :nullable, :primary_key)

    def self.columns(conn, collection, internal: false)
      rows = query(conn, SQL::Collection.describe(collection.to_s))
      rows = rows.reject { |r| r["field"].to_s.start_with?("__") } unless internal

      rows.group_by { |r| r["field"].to_s }.map do |field, dups|
        primary  = dups.any? { |r| r["type"].to_s.upcase.include?("PRIMARY KEY") }
        raw_type = dups.first["type"].to_s.sub(/\s+PRIMARY KEY\z/i, "")
        pg_type, oid = TypeMap.resolve(raw_type)
        nullable = !primary && dups.all? { |r| r["nullable"].to_s == "true" }

        Column.new(name: field, type: raw_type, pg_type: pg_type, oid: oid,
                   nullable: nullable, primary_key: primary)
      end
    end

    def self.collections(conn)
      query(conn, SQL::Collection.show).map { |r| r["name"] }
    end

    def self.query(conn, sql)
      result = conn.respond_to?(:exec) ? conn.exec(sql) : conn.run(sql)
      result.to_a
    end
    private_class_method :query
  end
end
