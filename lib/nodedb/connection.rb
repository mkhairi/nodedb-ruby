require "pg"

module NodeDB
  # Thin wrapper around PG::Connection with NodeDB defaults.
  # Use directly when no ORM is involved (scripts, Sequel, etc.).
  #
  #   conn = NodeDB::Connection.connect(host: "localhost", dbname: "mydb",
  #                                     user: "nodedb", password: "secret")
  #   result = conn.exec("SHOW COLLECTIONS")
  class Connection
    DEFAULT_PORT = 6432

    # Returns a raw PG::Connection to NodeDB.
    # Merges NodeDB defaults (port 6432) before delegating to PG.connect.
    def self.connect(host: "localhost", port: DEFAULT_PORT, dbname:, user:, password:, **opts)
      PG.connect(host: host, port: port, dbname: dbname, user: user, password: password, **opts)
    end
  end
end
