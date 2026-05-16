module NodeDB
  module Native
    # Query result over the native protocol.
    #
    # Mirrors the slice of PG::Result that the NodeDB SQL builders and the
    # downstream adapters actually touch (#fields, #values, #each yielding
    # column=>value hashes, #ntuples, #cmd_tuples) so the existing TypeMap
    # casting path keeps working unchanged.
    class Result
      include Enumerable

      attr_reader :columns, :rows, :rows_affected

      def initialize(columns:, rows:, rows_affected: 0)
        @columns = columns || []
        @rows = rows || []
        @rows_affected = rows_affected || 0
      end

      def fields = @columns

      def values = @rows

      def ntuples = @rows.length
      alias count ntuples
      alias size ntuples
      alias length ntuples

      def cmd_tuples = @rows_affected

      def each
        return to_enum(:each) unless block_given?

        @rows.each { |row| yield @columns.zip(row).to_h }
      end

      def [](index) = (row = @rows[index]) && @columns.zip(row).to_h

      def first = self[0]

      def empty? = @rows.empty?
    end
  end
end
