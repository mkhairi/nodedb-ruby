module NodeDB
  # Row-at-a-time result streaming over the :pg transport, for large
  # vector / FTS / timeseries scans that shouldn't be buffered in one
  # PG::Result.
  #
  #   NodeDB::Streaming.each_row(conn, "SELECT ... FROM big") do |row|
  #     # row is a Hash, same shape as conn.exec(...).each
  #   end
  #
  #   NodeDB::Streaming.each_row(conn, sql).lazy.take(100)  # Enumerator form
  #
  # Uses libpq single-row mode (send_query + set_single_row_mode), so
  # rows arrive as the server produces them. Breaking out early cancels
  # the in-flight query and drains the connection, so the connection
  # stays usable afterwards. :pg connections only — the :native
  # transport buffers whole results by design.
  module Streaming
    def self.each_row(conn, sql)
      raise ArgumentError, "streaming needs a PG::Connection (:pg transport)" unless conn.is_a?(PG::Connection)
      return enum_for(:each_row, conn, sql) unless block_given?

      conn.send_query(sql)
      conn.set_single_row_mode
      finished = false
      begin
        while (result = conn.get_result)
          begin
            result.check
            result.each { |row| yield row }
          ensure
            result.clear
          end
        end
        finished = true
      rescue PG::Error => e
        finished = true
        drain(conn)
        raise QueryError, e.message
      ensure
        unless finished # early break / raise from the caller's block
          conn.cancel
          drain(conn)
        end
      end
      nil
    end

    def self.drain(conn)
      while (result = conn.get_result)
        result.clear
      end
    rescue PG::Error
      nil
    end
    private_class_method :drain
  end
end
