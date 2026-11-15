require "connection_pool"

module NodeDB
  # Thread-safe pool of NodeDB connections (either transport).
  #
  #   pool = NodeDB::Pool.new(size: 5, timeout: 5,
  #                           dbname: "default", user: "nodedb", password: "...")
  #   pool.with { |conn| conn.exec("SELECT 1") }
  #   pool.exec("SELECT 1")   # checkout + exec + checkin
  #   pool.shutdown
  #
  # Connections are created lazily on first checkout via
  # NodeDB::Connection.connect, so `protocol: :native` and every other
  # connect option pass straight through. A PG connection that dies stays
  # in the pool. A native connection that closed itself is dropped at
  # checkin. Call #reload to discard and reconnect all of them.
  class Pool
    def initialize(size: 5, timeout: 5, **connect_opts)
      @pool = ConnectionPool.new(size: size, timeout: timeout) do
        Connection.connect(**connect_opts)
      end
    end

    # A native connection closes itself after a failed request. Drop it from
    # the pool so the next checkout reconnects. PG connections keep the
    # documented #reload behaviour.
    def with
      @pool.with do |conn|
        yield conn
      ensure
        @pool.discard_current_connection(&:close) if conn.respond_to?(:closed?) && conn.closed?
      end
    end

    def exec(sql)
      with { |conn| conn.exec(sql) }
    end

    # Close every idle connection and let future checkouts reconnect.
    def reload
      @pool.reload { |conn| conn.close }
    end

    def shutdown
      @pool.shutdown { |conn| conn.close }
    end

    def size
      @pool.size
    end

    def available
      @pool.available
    end
  end
end
