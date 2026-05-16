RSpec.describe NodeDB::Native::Result do
  subject(:result) do
    described_class.new(
      columns: %w[id name],
      rows: [[1, "ada"], [2, "lin"]],
      rows_affected: 0
    )
  end

  it "exposes columns via #fields" do
    expect(result.fields).to eq(%w[id name])
  end

  it "exposes raw rows via #values" do
    expect(result.values).to eq([[1, "ada"], [2, "lin"]])
  end

  it "counts tuples" do
    expect(result.ntuples).to eq(2)
    expect(result.count).to eq(2)
  end

  it "reports affected rows via #cmd_tuples" do
    expect(described_class.new(columns: [], rows: [], rows_affected: 5).cmd_tuples).to eq(5)
  end

  it "yields column=>value hashes via #each (PG::Result-shaped)" do
    expect(result.map { |r| r }).to eq(
      [{ "id" => 1, "name" => "ada" }, { "id" => 2, "name" => "lin" }]
    )
  end

  it "is Enumerable and supports #to_a / #first / #[]" do
    expect(result).to be_a(Enumerable)
    expect(result.first).to eq({ "id" => 1, "name" => "ada" })
    expect(result[1]).to eq({ "id" => 2, "name" => "lin" })
    expect(result.to_a.size).to eq(2)
  end

  it "treats an empty result safely" do
    empty = described_class.new(columns: [], rows: [], rows_affected: 0)
    expect(empty.ntuples).to eq(0)
    expect(empty.to_a).to eq([])
    expect(empty.first).to be_nil
  end
end
