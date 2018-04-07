module UniversalRecommender
  class Engine
    attr_accessor :access_key, :engine_port, :event_port, :host, :threads

    # Instantiates a new UniversalRecommender
    #
    # @param config [Hash] The configuration for the UniversalRecommender engine
    # @option config [String]  :access_key The access key for the PredictionIO
    #   application that is running the UniversalRecommender engine.
    # @option config [Integer] :engine_port The port number on which the
    #   UniversalRecommender engine is running.
    # @option config [Integer] :event_port The port number on which the
    #   PredictionIO event server is running.
    # @option config [String]  :host Host where the UniversalRecommender can be
    #   reached.
    # @option config [String]  :threads Number of threads for async requests to
    #   UniversalRecommender.
    #
    def initialize(config = {})
      self.access_key = config.fetch(:access_key, ENV['UR_ACCESS_KEY'])
      self.engine_port = config.fetch(:engine_port, ENV['UR_ENGINE_PORT'])
      self.event_port = config.fetch(:event_port, ENV['UR_EVENT_PORT'])
      self.host = config.fetch(:host, ENV['UR_HOST'])
      self.threads = config.fetch(:threads, ENV['UR_THREADS']).to_i
    end

    # Returns a query object for this engine.
    #
    # @return UniversalRecommender::Query
    def query
      UniversalRecommender::Query.new(engine: self)
    end

    # Instantiate an instance of PredictionIO::EventClient for this engine.
    #
    # @return PredictionIO::EventClient
    #
    def event_client
      @event_client ||= PredictionIO::EventClient.new(access_key, "http://#{host}:#{event_port}",
        threads)
    end

    # Instantiate an instance of PredictionIO::EngineClient for this engine.
    #
    # @return PredictionIO::EngineClient
    def engine_client
      @engine_client ||= PredictionIO::EngineClient.new("http://#{host}:#{engine_port}")
    end

    # Executes a query against the engine and returns the item scores.
    #
    # @param query [UniversalRecommender::Query]
    # @return [Array<Hash>] An array of hashes with an item and score for each
    #   recommendation result returned.
    # @param reifier_options [Hash{Symbol => anything}]
    #
    # @example
    #   engine.execute_query(query)
    #   # => [{"item" => "i-1", "score" => 1.0}]
    #
    def execute_query(query, reify: true, **reifier_options)
      query_results = engine_client.send_query(query.query_hash)
        .fetch('itemScores', [])

      if reify
        reify(query_results, **reifier_options)
      else
        query_results
      end
    end

    # Reify the results of a query if the engine reifier is set. is defined. If
    # the engine reifier is not set then the query results will be returned as
    # is. Any reifier options passed in will be passed to the reifier.
    #
    # @param item_scores [Array<Hash>] An array of item and scores from an
    #   executed query.
    # @param reifier_options [Hash{Symbol => anything}]
    def reify(query_results, **reifier_options)
      return query_results unless defined? reifier

      reifier(query_results, **reifier_options)
    end

    # Creates or updates an item or user.
    #
    # @param type [String] Either 'user' or 'item' to indicate which type of
    #   entity you are creating or updating.
    # @param id [String] The ID of the entity to be created or updated.
    # @param properties [Hash{Symbol,String => Array<#to_s>}] A hash of entity
    #   specific preoperties.
    #
    # @note Only 'item' properties are used when filtering results in queries.
    #
    # @example Create or update a user
    #   engine.upsert(type: 'user', id: 'u-1', properties: {age: ['18-25']})
    #
    # @example Create or update an item
    #   engine.upsert(type: 'item', id: 'i-1', properties: {available: ['yes']})
    #
    def upsert_entity(type:, id:, properties: {})
      event_client.create_event('$set', type, id, {
        properties: properties
      })
    end

    # Exports an item or user to a JSON Lines file.
    #
    # @param io   [IO] JSON Lines file that is being written to.
    # @param type [String] Either 'user' or 'item' to indicate which type of
    #   entity you are creating or updating.
    # @param id [String] The ID of the entity to be created or updated.
    # @param properties [Hash{Symbol,String => Array<#to_s>}] A hash of entity
    #   specific preoperties.
    #
    def export_entity(io: ,type:, id:, properties: {})
      entity_hash = {
        event: '$set',
        entityType: type,
        entityId: id,
        properties: properties
      }
      io.puts(JSON.dump(entity_hash))
    end

    # Records an event that took place between a user and an item
    #
    # @param type [String] The type of event.
    # @param user [String] The ID of a user.
    # @param item [String] The ID of an item.
    # @param properties [Hash{Symbol,String => Array<#to_s>}] A hash of event
    #   specific properties.
    # @param at [Time] The time at which the event occurred. Defaults to current
    #   time.
    #
    # @example User u-1 viewed Item i-1
    #   engine.record_event(type: 'viewed-item', user: 'u-1', item: 'i-1')
    #
    def record_event(type:, user:, item:, properties: {}, at: Time.current)
      event_client.create_event(type, 'user', user, {
        targetEntityType: 'item',
        targetEntityId: item,
        properties: properties,
        eventTime: at.to_s(:iso8601)
      })
    end

    # Exports an event that took place between a user and an item to a JSON Lines
    # file.
    #
    # @param io    [IO] JSON Lines file that is being written to.
    # @param type [String] The type of event.
    # @param user [String] The ID of a user.
    # @param item [String] The ID of an item.
    # @param properties [Hash{Symbol,String => Array<#to_s>}] A hash of event
    #   specific properties.
    # @param at [Time] The time at which the event occurred. Defaults to current
    #   time.
    #
    def export_event(io:, type:, user:, item:, properties: {}, at: Time.current)
      event_hash = {
        event: type,
        entityType: 'user',
        entityId: user,
        targetEntityType: 'item',
        targetEntityId: item,
        properties: properties,
        eventTime: at.to_s(:iso8601)
      }
      io.puts(JSON.dump(event_hash))
    end
  end
end
