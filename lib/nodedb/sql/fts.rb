module NodeDB
  module SQL
    # SQL builders for NodeDB full-text search engine.
    module FTS
      # Returns a SELECT ... WHERE text_match() SQL string.
      # Uses NodeDB's SQL FTS syntax: text_match(col, query) predicate +
      # bm25_score(col, query) for relevance ordering.
      #
      # @param table  [String] pre-quoted table/collection name
      # @param column [String] pre-quoted column name (unquoted identifier)
      # @param query  [String] pre-quoted search term string
      # @param limit  [Integer]
      # @param fuzzy  [Boolean] enable fuzzy matching (distance: 2)
      def self.search(table:, column:, query:, limit:, fuzzy: false)
        fuzzy_opts = fuzzy ? ", { fuzzy: true, distance: 2 }" : ""
        "SELECT *, bm25_score(#{column}, #{query}) AS bm25_score " \
        "FROM #{table} " \
        "WHERE text_match(#{column}, #{query}#{fuzzy_opts}) " \
        "ORDER BY bm25_score DESC " \
        "LIMIT #{limit.to_i}"
      end
    end
  end
end
