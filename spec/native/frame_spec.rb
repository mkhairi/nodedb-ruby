require "stringio"

RSpec.describe NodeDB::Native::Frame do
  describe ".hello_payload" do
    subject(:bytes) { described_class.hello_payload }

    it "is exactly 16 bytes" do
      expect(bytes.bytesize).to eq(16)
    end

    it "starts with the NDBH magic, big-endian" do
      magic = bytes[0, 4].unpack1("N")
      expect(magic).to eq(0x4E44_4248)
    end

    it "encodes proto_min=1, proto_max=1" do
      proto_min, proto_max = bytes[4, 4].unpack("nn")
      expect(proto_min).to eq(1)
      expect(proto_max).to eq(1)
    end

    it "advertises the streaming..columnar capability bits (0x7F)" do
      caps_hi, caps_lo = bytes[8, 8].unpack("NN")
      caps = (caps_hi << 32) | caps_lo
      expect(caps).to eq(0x7F)
    end
  end

  describe ".read_handshake_ack" do
    def ack_buffer(server_version:, proto_version: 1, capabilities: 0x80)
      sv = server_version.b
      buf = +""
      buf << [0x4E44_4241].pack("N")        # NDBA magic
      buf << [proto_version].pack("n")      # proto_version u16
      buf << [capabilities >> 32, capabilities & 0xFFFF_FFFF].pack("NN")
      buf << [sv.bytesize].pack("C")        # server_version_len u8
      buf << sv                             # server_version bytes
      buf << [1].pack("C")                  # limits-present flag
      7.times { buf << [0, 0].pack("CN") }  # 7 limit fields x 5 bytes
      buf
    end

    it "decodes proto_version, capabilities and server_version from an NDBA frame" do
      io = StringIO.new(ack_buffer(server_version: "NodeDB 0.2.1", capabilities: 0xFF))
      ack = described_class.read_handshake_ack(io)
      expect(ack.proto_version).to eq(1)
      expect(ack.capabilities).to eq(0xFF)
      expect(ack.server_version).to eq("NodeDB 0.2.1")
    end

    it "raises ConnectionError on an NDBE error frame" do
      err = +""
      err << "NDBE".b
      err << [1].pack("C")          # code = VersionMismatch
      msg = "version mismatch".b
      err << [msg.bytesize].pack("C")
      err << msg
      io = StringIO.new(err)
      expect { described_class.read_handshake_ack(io) }
        .to raise_error(NodeDB::ConnectionError, /version mismatch/)
    end

    it "raises ConnectionError on an unknown magic" do
      io = StringIO.new(["DEAD".unpack1("N")].pack("N") + ("\x00" * 12))
      expect { described_class.read_handshake_ack(io) }
        .to raise_error(NodeDB::ConnectionError, /handshake/i)
    end
  end

  describe ".write_frame / .read_frame" do
    it "round-trips a payload through a length-prefixed frame" do
      io = StringIO.new(+"".b)
      described_class.write_frame(io, "hello-payload".b)
      io.rewind
      expect(described_class.read_frame(io)).to eq("hello-payload".b)
    end

    it "prefixes the payload with its big-endian u32 length" do
      io = StringIO.new(+"".b)
      described_class.write_frame(io, "abc".b)
      expect(io.string[0, 4].unpack1("N")).to eq(3)
    end

    it "raises when the server announces an oversized frame" do
      io = StringIO.new([NodeDB::Native::Frame::MAX_FRAME_SIZE + 1].pack("N"))
      expect { described_class.read_frame(io) }
        .to raise_error(NodeDB::ConnectionError, /too large/)
    end
  end
end
