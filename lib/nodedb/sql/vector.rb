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
        vector_literal = "ARRAY[#{finite_floats(embedding).join(", ")}]"
        sql = "SEARCH #{table} USING VECTOR(#{column}, #{vector_literal}, #{limit.to_i})"
        sql += " WHERE #{filter}" if filter
        sql
      end

      # Without this check a nil or non-numeric value becomes 0.0 and the search
      # runs on a meaningless vector. Fail loudly instead.
      def self.finite_floats(embedding)
        values = Array(embedding).map do |v|
          Float(v)
        rescue TypeError, ArgumentError
          raise ArgumentError, "embedding value #{v.inspect} is not numeric"
        end
        raise ArgumentError, "embedding is empty" if values.empty?
        raise ArgumentError, "embedding contains NaN or Infinity" unless values.all?(&:finite?)

        values
      end
      private_class_method :finite_floats
    end
  end
end
