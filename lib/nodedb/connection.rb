require "pg"

module NodeDB
  # Connection factory for NodeDB.
  #
  # Two transports, selected with `protocol:`:
  #
  #   :pg     (default) — PostgreSQL wire via the pg gem, port 6432.
  #                       Returns a raw PG::Connection (unchanged behaviour).
  #   :native           — NodeDB native binary protocol, port 6433.
  #                       Returns a NodeDB::Native::Connection (no libpq).
  #
  #   conn = NodeDB::Connection.connect(dbname: "mydb", user: "nodedb",
  #                                     password: "secret")
  #   conn = NodeDB::Connection.connect(dbname: "mydb", user: "nodedb",
  #                                     password: "secret", protocol: :native)
  class Connection
    DEFAULT_PORT        = 6432
    DEFAULT_NATIVE_PORT = 6433

    def self.connect(host: "localhost", port: nil, dbname:, user:, password: nil,
                      protocol: :pg, **opts)
      case protocol
      when :pg
        PG.connect(host: host, port: port || DEFAULT_PORT,
                   dbname: dbname, user: user, password: password, **opts)
      when :native
        NodeDB::Native::Connection.connect(
          host: host, port: port || DEFAULT_NATIVE_PORT,
          database: dbname, username: user, password: password, **opts
        )
      else
        raise ArgumentError,
              "unknown protocol #{protocol.inspect} (expected :pg or :native)"
      end
    end
  end
end
