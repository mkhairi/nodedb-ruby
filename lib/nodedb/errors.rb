module NodeDB
  Error = Class.new(StandardError)
  ConnectionError = Class.new(Error)
  TimeoutError = Class.new(ConnectionError)
  QueryError = Class.new(Error)
  CollectionError = Class.new(Error)
end
