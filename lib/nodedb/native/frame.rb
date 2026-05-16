module NodeDB
  module Native
    # Wire framing for the NodeDB native binary protocol.
    #
    # The handshake is a fixed, *unprefixed* byte exchange. Every frame after
    # it is a 4-byte big-endian length prefix followed by a MessagePack
    # payload. Mirrors nodedb-client/src/native/connection/mod.rs.
    module Frame
      HELLO_MAGIC       = 0x4E44_4248 # "NDBH"
      HELLO_ACK_MAGIC   = 0x4E44_4241 # "NDBA"
      HELLO_ERROR_MAGIC = 0x4E44_4245 # "NDBE"

      PROTO_MIN = 1
      PROTO_MAX = 1

      # Bits 0..6: streaming, graphrag, fts, crdt, spatial, timeseries,
      # columnar. Matches the Rust client's advertised set.
      CLIENT_CAPABILITIES = 0x7F

      FRAME_HEADER_LEN = 4
      MAX_FRAME_SIZE   = 16 * 1024 * 1024

      HELLO_ERROR_CODES = {
        0 => "BadMagic",
        1 => "VersionMismatch",
        2 => "Malformed"
      }.freeze

      Ack = Struct.new(:proto_version, :capabilities, :server_version, :limits, keyword_init: true)

      module_function

      # The 16-byte HelloFrame the client sends first.
      def hello_payload
        [
          HELLO_MAGIC,
          PROTO_MIN,
          PROTO_MAX,
          CLIENT_CAPABILITIES >> 32,
          CLIENT_CAPABILITIES & 0xFFFF_FFFF
        ].pack("NnnNN")
      end

      # Read the server's handshake reply. Returns an Ack on success;
      # raises NodeDB::ConnectionError on an NDBE frame or bad magic.
      def read_handshake_ack(io)
        magic = read_exactly(io, 4).unpack1("N")

        case magic
        when HELLO_ACK_MAGIC
          decode_ack(io)
        when HELLO_ERROR_MAGIC
          code = read_exactly(io, 1).unpack1("C")
          msg_len = read_exactly(io, 1).unpack1("C")
          message = msg_len.zero? ? "" : read_exactly(io, msg_len)
          label = HELLO_ERROR_CODES.fetch(code, "Unknown(#{code})")
          raise NodeDB::ConnectionError, "native handshake rejected (#{label}): #{message}"
        else
          raise NodeDB::ConnectionError,
                format("native handshake failed: unexpected magic 0x%08X", magic)
        end
      end

      # Write a length-prefixed frame.
      def write_frame(io, payload)
        io.write([payload.bytesize].pack("N"))
        io.write(payload)
        io.flush if io.respond_to?(:flush)
      end

      # Read one length-prefixed frame payload.
      def read_frame(io)
        len = read_exactly(io, FRAME_HEADER_LEN).unpack1("N")
        if len > MAX_FRAME_SIZE
          raise NodeDB::ConnectionError, "native response frame too large: #{len} bytes"
        end

        len.zero? ? "".b : read_exactly(io, len)
      end

      # Read exactly n bytes or raise (sockets may short-read).
      def read_exactly(io, n)
        buf = +"".b
        while buf.bytesize < n
          chunk = io.read(n - buf.bytesize)
          raise NodeDB::ConnectionError, "native connection closed mid-frame" if chunk.nil? || chunk.empty?

          buf << chunk
        end
        buf
      end

      def decode_ack(io)
        proto_version = read_exactly(io, 2).unpack1("n")
        caps_hi, caps_lo = read_exactly(io, 8).unpack("NN")
        capabilities = (caps_hi << 32) | caps_lo
        sv_len = read_exactly(io, 1).unpack1("C")
        server_version = sv_len.zero? ? "" : read_exactly(io, sv_len).force_encoding("UTF-8")

        limits = {}
        if (flag = read_exactly(io, 1).unpack1("C")) == 1
          %i[max_vector_dim max_top_k max_scan_limit max_batch_size
             max_crdt_delta_bytes max_query_text_bytes max_graph_depth].each do |name|
            present, value = read_exactly(io, 5).unpack("CN")
            limits[name] = value if present == 1
          end
        end

        Ack.new(
          proto_version: proto_version,
          capabilities: capabilities,
          server_version: server_version,
          limits: limits
        )
      end
      private_class_method :decode_ack
    end
  end
end
