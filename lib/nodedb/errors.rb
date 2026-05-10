module NodeDB
  Error             = Class.new(StandardError)
  ConnectionError   = Class.new(Error)
  QueryError        = Class.new(Error)
  CollectionError   = Class.new(Error)
end
