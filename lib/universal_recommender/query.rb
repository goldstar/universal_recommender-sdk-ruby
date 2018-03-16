module UniversalRecommender
  # +Query+ objects are used for building queries which can be run against the
  # Universal Recommender engine. Much of the business logic you want to run
  # is done from query objects.
  #
  # A query is composable. Each call will OR it's field values. Multiple calls
  # are ANDed together.
  #
  # @example Find items where the `field` value contains either `a` OR `b`
  #   query.where(field: [a, b])
  #
  # @example Find items where the `field` value contains `a` AND `b`
  #   query.where(field: a).where(field: b)
  #
  # @example Find items where the `field` value contains (`a` OR `b`) AND (`c` OR `d`)
  #   query.where(field: [a, b]).where(field: [c, d])
  #
  # By combining multiple calls you can achieve complex business rules. Be mindful
  # of the rules you are applying as you may negatively impact recommendations by
  # making assumptions _or_ by applying filters that ultimately remove all recommendations.
  #
  # @example A complex query
  #   query
  #     .for_user(1)
  #     .where(distribution_channel: 1, territory_ids: [1, 2, 3])
  #     .not(price_ranges: 'Comp')
  #     .boost(amount: 1.5, category_ids: [1])
  #
  class Query
    include Enumerable

    attr_reader :engine

    def initialize(engine:)
      @engine = engine
      @fields = []
    end

    # Personalize recommendations to a specific user
    #
    # @param user [#to_s] An object which can be coerced to a string which represents
    #   a unique user
    #
    def for_user(user)
      @user = user
      self
    end

    # Change the number of recommendations returned.
    #
    # @param limit [Integer]
    #
    def limit(limit)
      @limit = limit
      self
    end

    # Limit to items which are similar to another behaviorally
    #
    # @param item [#to_s] An object which can be coerced to a string represtning
    #   an item id
    #
    def similar_to(item)
      @item = item.to_s
      self
    end

    # Includes items based on it's properties
    #
    # @param conditions [Hash] A hash where keys are field names and values are
    #   an object or an array of objects which can be coerced to strings
    #
    # @example Include items in a specific distribution channel
    #   query.where(amount: 0.5, distribution_channel_ids: [1])
    #
    def where(**conditions)
      conditions.each do |field, values|
        add_bias(field: field, values: Array(values), bias: -1.0)
      end
      self
    end

    # Excludes items based on it's properties
    #
    # @param conditions [Hash] A hash where keys are field names and values are
    #   an object or an array of objects which can be coerced to strings
    #
    # @example Exclude items in a specific distribution channel
    #   query.not(amount: 0.5, distribution_channel_ids: [1])
    #
    def not(**conditions)
      conditions.each do |field, values|
        add_bias(field: field, values: Array(values), bias: 0.0)
      end
      self
    end

    # Boosts an item based on it's properties
    #
    # @param amount [#to_f] The amount to boost events which match the condition
    # @param conditions [Hash] A hash where keys are field names and values are
    #   strings or an array of strings.
    #
    # @example Boost an item which occurs on a specific day of the week
    #   query.where(amount: 1.02, day_of_week: [5, 6, 0])
    #
    def boost(amount:, **conditions)
      raise ArgumentError, ':amount must be greater than 1.0' if amount <= 1

      conditions.each do |field, values|
        add_bias(field: field, values: Array(values), bias: amount)
      end
      self
    end

    # Deboosts an item based on it's properties
    #
    # @param amount [#to_f] The amount to deboost events which match the condition
    # @param conditions [Hash] A hash where keys are field names and values are
    #   an object or an array of objects which can be coerced to strings
    #
    # @example Deboost an item which is in a category the user dislikes
    #   query.where(amount: 0.5, category_ids: [1])
    #
    def deboost(amount:, **conditions)
      if amount <= 0 || amount >= 1
        raise ArgumentError, ':amount must be between 0.0 and 1.0 exclusive'
      end

      conditions.each do |field, values|
        add_bias(field: field, values: Array(values), bias: amount)
      end
      self
    end

    # Returns a hash representing the query
    def query_hash
      {
        user: @user,
        item: @item,
        num: @limit,
        fields: @fields
      }.reject{|_,v| v.nil? }
    end

    def each
      return enum_for(:each) unless block_given?

      @engine.execute_query(self).each {|result| yield result }
    end

    private

    def add_bias(field:, values:, bias:)
      @fields << {
        name: field.to_s,
        values: values.map(&:to_s),
        bias: bias.to_f
      }
    end
  end
end
