class MongoPubsub
  include Celluloid
  include Celluloid::Logger

  class Subscription
    include Celluloid

    attr_reader :channel
    execute_block_on_receiver :on_message

    # @param [String] channel
    def initialize(channel)
      @channel = channel
      @wait_time = 0
      @queue = Queue.new
      async.process_queue
    end

    def push(data)
      @queue << data
    end

    def process_queue
      defer {
        while data = @queue.pop
          self.send_message(data)
        end
      }
    end

    # @param [Integer] wait
    def on_message(wait = 0, &block)
      @block = block
      after(wait){ self.terminate } if wait > 0
    end

    # @param [Hash] data
    def send_message(data)
      @block.call(data)
    end
  end

  attr_accessor :collection, :subscriptions

  # @param [Moped::Collection]
  def initialize(collection)
    @collection = collection
    @subscriptions = []
    async.tail!
  end

  # @param [String] channel
  def subscribe(channel, block)
    subscription = Subscription.new(channel)
    self.subscriptions << subscription
    block.call(subscription)
    sleep 0.001 until !subscription.alive?
    self.unsubscribe(subscription)
    true
  end

  # @param [Subscription] subscription
  def unsubscribe(subscription)
    subscription.terminate if subscription.alive?
    self.subscriptions.delete(subscription)
  end

  # @param [String] channel
  # @param [Hash] data
  def publish(channel, data)
    self.collection.insert(
      channel: channel,
      data: data,
      created_at: Time.now.utc
    )
  end

  # @param [String] channel
  # @param [Hash] data
  def self.publish(channel, data)
    @supervisor.actors.first.publish(channel, data)
  end

  # @param [String] channel
  # @param [Hash] data
  def self.publish_async(channel, data)
    @supervisor.actors.first.async.publish(channel, data)
  end

  # @param [String] channel
  def self.subscribe(channel, &block)
    @supervisor.actors.first.subscribe(channel, block)
  end

  def self.start!(collection)
    @supervisor = self.supervise(collection)
  end

  def self.clear!
    actor = @supervisor.actors.first
    actor.subscriptions.each do |subscription|
      actor.unsubscribe(subscription)
    end
  end

  private

  def tail!
    ensure_collection!
    defer {
      query = {created_at: {'$gte' => Time.now.utc}}
      begin
        info "#{self.class.name}: starting to tail collection"
        self.collection.find(query).sort('$natural' => 1).tailable.each do |item|
          channel = item['channel']
          data = item['data'].freeze
          subscribers = self.subscriptions.select{|s|
            begin
              s.alive? && s.channel == channel
            rescue Celluloid::DeadActorError
              false
            end
          }
          subscribers.each do |subscription|
            begin
              subscription.async.push(data) if subscription && subscription.alive?
            rescue Celluloid::DeadActorError
            end
          end
        end
      rescue => exc
        puts exc.class
        puts exc.message
        puts exc.backtrace
        error "#{self.class.name}: error while tailing: #{exc.message}"
        query = {created_at: {'$gte' => Time.now.utc}}
        sleep 0.1
        retry
      end
    }
  end

  def ensure_collection!
    unless self.collection.session.collection_names.include?(self.collection.name)
      self.collection.session.command(create: self.collection.name)
    end
    unless self.collection.capped?
      self.collection.session.command(
        convertToCapped: self.collection.name,
        capped: true,
        size: 24.megabytes
      )
      self.publish('test', {})
    end
  end
end
