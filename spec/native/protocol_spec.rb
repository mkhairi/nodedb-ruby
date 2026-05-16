require "msgpack"

RSpec.describe NodeDB::Native::Protocol do
  describe "opcode + field-id constants" do
    it "matches the NodeDB native protocol numbers" do
      expect(described_class::OP_AUTH).to eq(0x01)
      expect(described_class::OP_SQL).to eq(0x20)
      expect(described_class::OP_BEGIN).to eq(0x40)
      expect(described_class::OP_COMMIT).to eq(0x41)
      expect(described_class::OP_ROLLBACK).to eq(0x42)
      expect(described_class::FID_SQL).to eq(2)
      expect(described_class::FID_AUTH).to eq(1)
      expect(described_class::FID_DATABASE).to eq(83)
      expect(described_class::FID_SQL_PARAMS).to eq(84)
    end
  end

  describe ".encode_request" do
    it "produces [op, seq, [0x01, fields_map]] as MessagePack" do
      bytes = described_class.encode_request(
        op: described_class::OP_SQL,
        seq: 7,
        fields: { described_class::FID_SQL => "SELECT 1" }
      )
      decoded = MessagePack.unpack(bytes)
      expect(decoded).to eq([0x20, 7, [0x01, { 2 => "SELECT 1" }]])
    end

    it "emits an empty fields map when no fields are given" do
      bytes = described_class.encode_request(op: described_class::OP_PING, seq: 1, fields: {})
      expect(MessagePack.unpack(bytes)).to eq([0x02, 1, [0x01, {}]])
    end
  end

  describe ".decode_value" do
    it "decodes scalar Value tags" do
      expect(described_class.decode_value([0])).to be_nil
      expect(described_class.decode_value([1, true])).to be(true)
      expect(described_class.decode_value([2, 42])).to eq(42)
      expect(described_class.decode_value([3, 1.5])).to eq(1.5)
      expect(described_class.decode_value([4, "hi"])).to eq("hi")
      expect(described_class.decode_value([8, "550e8400-e29b-41d4-a716-446655440000"]))
        .to eq("550e8400-e29b-41d4-a716-446655440000")
    end

    it "recurses into Array and Object values" do
      arr = [6, [[2, 1], [4, "x"]]]
      expect(described_class.decode_value(arr)).to eq([1, "x"])
      obj = [7, { "k" => [2, 9] }]
      expect(described_class.decode_value(obj)).to eq({ "k" => 9 })
    end

    it "decodes a Vector tag into an array of f32 floats" do
      packed = [1.0, 2.5].pack("e2") # little-endian f32 x2
      result = described_class.decode_value([20, packed])
      expect(result.length).to eq(2)
      expect(result[0]).to be_within(1e-6).of(1.0)
      expect(result[1]).to be_within(1e-6).of(2.5)
    end
  end

  describe ".decode_response" do
    it "symbolizes a NativeResponse map and decodes rows of Values" do
      payload = MessagePack.pack(
        "seq"           => 3,
        "status"        => 0,
        "columns"       => %w[id name],
        "rows"          => [[[2, 1], [4, "ada"]], [[2, 2], [0]]],
        "rows_affected" => 0,
        "watermark_lsn" => 11
      )
      resp = described_class.decode_response(payload)
      expect(resp.status).to eq(0)
      expect(resp.columns).to eq(%w[id name])
      expect(resp.rows).to eq([[1, "ada"], [2, nil]])
      expect(resp.rows_affected).to eq(0)
    end

    it "exposes error code and message" do
      payload = MessagePack.pack(
        "seq"    => 1,
        "status" => 2,
        "error"  => { "code" => "42P01", "message" => "undefined table" }
      )
      resp = described_class.decode_response(payload)
      expect(resp.status).to eq(2)
      expect(resp.error_code).to eq("42P01")
      expect(resp.error_message).to eq("undefined table")
    end
  end

  describe ".encode_auth" do
    it "encodes Trust as [\"Trust\", [username]] when no password" do
      expect(described_class.encode_auth(username: "admin")).to eq(["Trust", ["admin"]])
    end

    it "encodes Password as [\"Password\", [username, password]]" do
      expect(described_class.encode_auth(username: "nodedb", password: "s3cret"))
        .to eq(["Password", ["nodedb", "s3cret"]])
    end
  end

  describe ".encode_value" do
    it "round-trips scalars through decode_value" do
      [nil, true, false, 42, -7, 3.14, "hello"].each do |v|
        encoded = described_class.encode_value(v)
        expect(described_class.decode_value(encoded)).to eq(v)
      end
    end
  end
end
