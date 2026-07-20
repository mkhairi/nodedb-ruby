require "spec_helper"

RSpec.describe NodeDB::TypeMap do
  describe ".resolve" do
    NodeDB::TypeMap::MAP.each do |nodedb_type, expected|
      it "resolves #{nodedb_type.inspect} to #{expected.inspect}" do
        expect(described_class.resolve(nodedb_type)).to eq(expected)
      end
    end

    it "strips precision/scale before lookup" do
      expect(described_class.resolve("VARCHAR(255)")).to eq(["character varying", 1043])
    end

    it "is case-insensitive" do
      expect(described_class.resolve("integer")).to eq(["integer", 23])
    end

    it "resolves the multi-word TIMESTAMP TIME_KEY key" do
      expect(described_class.resolve("TIMESTAMP TIME_KEY"))
        .to eq(["timestamp without time zone", 1114])
    end

    it "falls back to text for an unknown type" do
      expect(described_class.resolve("WEIRD")).to eq(["text", 25])
    end

    it "falls back to text for nil input" do
      expect(described_class.resolve(nil)).to eq(["text", 25])
    end

    it "falls back to text for empty input" do
      expect(described_class.resolve("")).to eq(["text", 25])
    end
  end
end
