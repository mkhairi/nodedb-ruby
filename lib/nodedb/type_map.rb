module NodeDB
  module TypeMap
    # Maps NodeDB column type names to [pg_type_string, pg_oid].
    # OIDs match the pg_type entries NodeDB exposes via pgwire.
    MAP = {
      "TEXT"               => ["text",                          25],
      "VARCHAR"            => ["character varying",           1043],
      "FLOAT"              => ["double precision",             701],
      "FLOAT4"             => ["real",                         700],
      "FLOAT8"             => ["double precision",             701],
      "DOUBLE"             => ["double precision",             701],
      "INTEGER"            => ["integer",                       23],
      "INT"                => ["integer",                       23],
      "INT4"               => ["integer",                       23],
      "INT2"               => ["smallint",                      21],
      "SMALLINT"           => ["smallint",                      21],
      "INT8"               => ["bigint",                        20],
      "BIGINT"             => ["bigint",                        20],
      "BOOLEAN"            => ["boolean",                       16],
      "BOOL"               => ["boolean",                       16],
      "TIMESTAMP"          => ["timestamp without time zone", 1114],
      "TIMESTAMP TIME_KEY" => ["timestamp without time zone", 1114],
      "TIMESTAMPTZ"        => ["timestamp with time zone",    1184],
      "DATE"               => ["date",                        1082],
      "UUID"               => ["uuid",                        2950],
      "JSON"               => ["json",                         114],
      "JSONB"              => ["jsonb",                       3802],
      "NUMERIC"            => ["numeric",                     1700],
      "DECIMAL"            => ["numeric",                     1700],
      "BYTEA"              => ["bytea",                          17],
    }.freeze

    # Resolve a NodeDB type name to [pg_type_string, pg_oid].
    # Strips precision/scale (e.g. "VARCHAR(255)" → "VARCHAR") before lookup.
    # Falls back to ["text", 25] for unknown types.
    def self.resolve(nodedb_type)
      base = nodedb_type.to_s.upcase.split("(").first.strip
      MAP[base] || ["text", 25]
    end
  end
end
