module NodeDB
  module SQL
    # SQL builders for NodeDB vector search.
    module Vector
      # Returns a SEARCH ... USING VECTOR() SQL string.
      #
      # @param table     [String] pre-quoted table/collection name
      # @param column    [String] pre-quoted column name
      # @param embedding [Array<Float>] query vector
      # @param limit     [Integer] number of nearest neighbours
      # @param filter    [String, nil] optional SQL WHERE fragment
      def self.search(table:, column:, embedding:, limit:, filter: nil)
        vector_literal = "ARRAY[#{embedding.map(&:to_f).join(", ")}]"
        sql = "SEARCH #{table} USING VECTOR(#{column}, #{vector_literal}, #{limit.to_i})"
        sql += " WHERE #{filter}" if filter
        sql
      end
    end
  end
end
