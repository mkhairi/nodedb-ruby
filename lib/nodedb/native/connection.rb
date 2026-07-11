require "socket"

module NodeDB
  module Native
    # A single connection to NodeDB over the native binary protocol
    # (TCP, MessagePack-framed, default port 6433). No pg / libpq.
    #
    #   conn = NodeDB::Native::Connection.connect(
    #     database: "nodedb", username: "nodedb", password: "secret")
    #   conn.run("SELECT 1").to_a
    class Connection
      DEFAULT_PORT = 6433

      attr_reader :server_version, :capabilities, :limits, :connection_parameters

      def self.connect(database:, username:, host: "localhost", port: DEFAULT_PORT,
        password: nil, connect_timeout: nil, read_timeout: nil, **_ignored)
        new(host: host, port: port, database: database, username: username,
          password: password, connect_timeout: connect_timeout, read_timeout: read_timeout)
      end

      def initialize(host:, port:, database:, username:, password:, connect_timeout: nil, read_timeout: nil)
        @connection_parameters = {
          host: host, port: port, database: database,
          username: username, password: password, connect_timeout: connect_timeout,
          read_timeout: read_timeout
        }
        @read_timeout = read_timeout
        @seq = 0
        @socket =
          if connect_timeout
            Socket.tcp(host, port, connect_timeout: connect_timeout)
          else
            TCPSocket.new(host, port)
          end
        @socket.sync = true if @socket.respond_to?(:sync=)

        @socket.write(Frame.hello_payload)
        handshake_deadline = connect_timeout && Process.clock_gettime(Process::CLOCK_MONOTONIC) + connect_timeout
        ack = Frame.read_handshake_ack(@socket, deadline: handshake_deadline)
        @server_version = ack.server_version
        @capabilities = ack.capabilities
        @limits = ack.limits

        authenticate(username, password, database)
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
        raise NodeDB::ConnectionError, "native connect failed: #{e.message}"
      end

      def run(sql)
        to_result(send_op(Protocol::OP_SQL, {Protocol::FID_SQL => sql}))
      end
      alias_method :exec, :run
      alias_method :query, :run
      alias_method :execute, :run

      def run_params(sql, params = [])
        fields = {Protocol::FID_SQL => sql}
        unless params.nil? || params.empty?
          fields[Protocol::FID_SQL_PARAMS] = params.map { |p| Protocol.encode_value(p) }
        end
        to_result(send_op(Protocol::OP_SQL, fields))
      end
      alias_method :exec_params, :run_params

      def begin
        check(send_op(Protocol::OP_BEGIN, {}))
      end

      def commit
        check(send_op(Protocol::OP_COMMIT, {}))
      end

      def rollback
        check(send_op(Protocol::OP_ROLLBACK, {}))
      end

      def set_param(key, value)
        check(send_op(Protocol::OP_SET,
          {Protocol::FID_KEY => key, Protocol::FID_VALUE => value}))
      end

      def show_param(key)
        resp = send_op(Protocol::OP_SHOW, {Protocol::FID_KEY => key})
        raise_if_error(resp)
        resp.rows.dig(0, 0)
      end

      def ping
        check(send_op(Protocol::OP_PING, {}))
      end

      def close
        @socket.close unless @socket.closed?
      rescue IOError
        nil
      end

      def closed?
        @socket.closed?
      end

      private

      def authenticate(username, password, database)
        fields = {
          Protocol::FID_AUTH => Protocol.encode_auth(username: username, password: password),
          Protocol::FID_DATABASE => database
        }
        resp = send_op(Protocol::OP_AUTH, fields)
        return if resp.ok?

        raise NodeDB::ConnectionError, "native auth failed: #{resp.error_message}"
      end

      def next_seq
        @seq += 1
      end

      def send_op(op, fields)
        Frame.write_frame(@socket, Protocol.encode_request(op: op, seq: next_seq, fields: fields))
        deadline = @read_timeout && Process.clock_gettime(Process::CLOCK_MONOTONIC) + @read_timeout
        read_response(deadline)
      end

      # Collapse a Partial (streamed) response into one Response.
      def read_response(deadline = nil)
        acc = nil
        loop do
          resp = Protocol.decode_response(Frame.read_frame(@socket, deadline: deadline))
          if resp.partial?
            acc ? acc.rows.concat(resp.rows) : (acc = resp)
            next
          end

          return resp unless acc

          acc.rows.concat(resp.rows)
          acc.status = Protocol::STATUS_OK
          acc.rows_affected = resp.rows_affected if resp.rows_affected
          return acc
        end
      end

      def to_result(resp)
        raise_if_error(resp)
        Result.new(
          columns: resp.columns || [],
          rows: resp.rows || [],
          rows_affected: resp.rows_affected || 0
        )
      end

      def check(resp)
        raise_if_error(resp)
        true
      end

      def raise_if_error(resp)
        return unless resp.error?

        raise NodeDB::QueryError,
          [resp.error_code, resp.error_message].compact.join(": ")
      end
    end
  end
end
