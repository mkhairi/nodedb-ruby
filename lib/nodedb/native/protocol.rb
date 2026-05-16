require "msgpack"

module NodeDB
  module Native
    # MessagePack request/response codec for the NodeDB native protocol.
    #
    # Request  = [op, seq, [0x01, {fid => value, ...}]]   (NativeRequest)
    # Response = {"seq"=>, "status"=>, "columns"=>, "rows"=>, ...}
    # Value    = [tag, payload]  (hand-rolled tagged encoding)
    module Protocol
      OP_AUTH     = 0x01
      OP_PING     = 0x02
      OP_STATUS   = 0x03
      OP_SQL      = 0x20
      OP_DDL      = 0x21
      OP_SET      = 0x30
      OP_SHOW     = 0x31
      OP_RESET    = 0x32
      OP_BEGIN    = 0x40
      OP_COMMIT   = 0x41
      OP_ROLLBACK = 0x42

      FID_AUTH       = 1
      FID_SQL        = 2
      FID_KEY        = 3
      FID_VALUE      = 4
      FID_DATABASE   = 83
      FID_SQL_PARAMS = 84

      # RequestFields::Text discriminant.
      DISC_TEXT = 0x01

      STATUS_OK      = 0
      STATUS_PARTIAL = 1
      STATUS_ERROR   = 2

      Response = Struct.new(
        :seq, :status, :columns, :rows, :rows_affected,
        :watermark_lsn, :error_code, :error_message, :auth, :warnings,
        keyword_init: true
      ) do
        def ok?      = status == STATUS_OK
        def partial? = status == STATUS_PARTIAL
        def error?   = status == STATUS_ERROR
      end

      module_function

      def encode_request(op:, seq:, fields:)
        MessagePack.pack([op, seq, [DISC_TEXT, fields]])
      end

      # AuthMethod is a zerompk-derived enum: [variant_ident, [field values]].
      # Trust { username } | Password { username, password }.
      def encode_auth(username:, password: nil)
        if password.nil?
          ["Trust", [username]]
        else
          ["Password", [username, password]]
        end
      end

      def decode_response(bytes)
        m = MessagePack.unpack(bytes)
        err = m["error"]
        code, message = extract_error(err)

        Response.new(
          seq: m["seq"],
          status: m["status"],
          columns: m["columns"],
          rows: (m["rows"] || []).map { |row| row.map { |cell| decode_value(cell) } },
          rows_affected: m["rows_affected"],
          watermark_lsn: m["watermark_lsn"],
          error_code: code,
          error_message: message,
          auth: m["auth"],
          warnings: m["warnings"] || []
        )
      end

      # Decode a single [tag, payload] Value into a native Ruby object.
      def decode_value(v)
        return v unless v.is_a?(Array)

        case v[0]
        when 0  then nil
        when 1, 2, 3, 4, 8, 9, 15 then v[1]            # bool/int/float/str/uuid/ulid/regex
        when 5  then v[1]                              # bytes (binary string)
        when 6, 14 then v[1].map { |c| decode_value(c) } # array / set
        when 7  then v[1].transform_values { |c| decode_value(c) }
        when 20 then v[1].unpack("e*")                 # vector: f32 little-endian
        when 16 then { start: decode_value(v[1]), end: decode_value(v[2]), inclusive: v[3] }
        when 17 then { table: v[1], id: v[2] }
        else v[1] # 10-13,18,19: temporal/decimal/geometry — raw passthrough (phase 2)
        end
      end

      # Encode a scalar Ruby value into a [tag, payload] Value (for bound params).
      def encode_value(v)
        case v
        when nil          then [0]
        when true, false  then [1, v]
        when Integer      then [2, v]
        when Float        then [3, v]
        when String
          v.encoding == Encoding::BINARY ? [5, v] : [4, v]
        when Symbol       then [4, v.to_s]
        when Array        then [6, v.map { |e| encode_value(e) }]
        when Hash         then [7, v.transform_values { |e| encode_value(e) }]
        else [4, v.to_s]
        end
      end

      # ErrorPayload/auth derive shape isn't pinned from source (zerompk
      # default derive); accept either a map or a positional array.
      def extract_error(err)
        case err
        when Hash  then [err["code"], err["message"]]
        when Array then [err[0], err[1]]
        else [nil, nil]
        end
      end
      private_class_method :extract_error
    end
  end
end
