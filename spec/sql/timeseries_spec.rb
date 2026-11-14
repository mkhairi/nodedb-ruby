require "spec_helper"
require "nodedb/sql/timeseries"

RSpec.describe NodeDB::SQL::Timeseries do
  describe ".time_bucket" do
    it "renders time_bucket() aliased :bucket by default" do
      sql = described_class.time_bucket("1 hour")

      expect(sql).to eq("time_bucket('1 hour', timestamp) AS bucket")
    end

    it "uses a custom alias when as: is given" do
      sql = described_class.time_bucket("1 hour", as: :hr)

      expect(sql).to eq("time_bucket('1 hour', timestamp) AS hr")
    end

    it "accepts short and compound intervals" do
      ["5m", "1 minute", "2 hours 30 minutes", "500"].each do |interval|
        sql = described_class.time_bucket(interval)

        expect(sql).to be_a(String)
        expect(sql).to include("time_bucket('#{interval}', timestamp)")
      end
    end

    it "rejects an interval with a quote" do
      expect { described_class.time_bucket("5 o'clock") }
        .to raise_error(ArgumentError, /interval/)
    end

    it "rejects an interval with punctuation" do
      expect { described_class.time_bucket("1h); DROP") }
        .to raise_error(ArgumentError)
    end

    it "rejects an empty interval" do
      expect { described_class.time_bucket("") }
        .to raise_error(ArgumentError)
    end

    it "rejects a non-identifier alias" do
      expect { described_class.time_bucket("1h", as: "b; x") }
        .to raise_error(ArgumentError, /as/)
    end
  end

  describe ".epoch_ms" do
    it "converts a Time to Unix milliseconds" do
      time = Time.at(1700000000)

      expect(described_class.epoch_ms(time)).to eq(1700000000000)
    end

    it "keeps milliseconds" do
      expect(described_class.epoch_ms(Time.at(1, 500, :millisecond))).to eq(1500)
    end

    it "floors sub-millisecond parts" do
      expect(described_class.epoch_ms(Time.at(1, 500_999, :usec))).to eq(1500)
    end

    it "accepts an Integer" do
      expect(described_class.epoch_ms(1_700_000_000)).to eq(1_700_000_000_000)
    end

    it "falls back to to_i" do
      expect(described_class.epoch_ms(Struct.new(:to_i).new(2))).to eq(2000)
    end
  end

  describe ".since_clause" do
    it "renders a timestamp > epoch_ms(time) fragment" do
      time = Time.at(1700000000)

      expect(described_class.since_clause(time)).to eq("timestamp > 1700000000000")
    end

    it "uses millisecond precision" do
      time = Time.at(1_700_000_000, 250, :millisecond)

      expect(described_class.since_clause(time)).to eq("timestamp > 1700000000250")
    end
  end

  describe ".until_clause" do
    it "renders a timestamp <= epoch_ms(time) fragment" do
      time = Time.at(1700000000)

      expect(described_class.until_clause(time)).to eq("timestamp <= 1700000000000")
    end
  end
end
