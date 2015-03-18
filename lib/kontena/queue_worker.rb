require 'msgpack'
require_relative 'logging'

module Kontena
  class QueueWorker
    include Kontena::Logging

    LOG_NAME = 'QueueWorker'

    attr_reader :queue, :client

    ##
    # @param [WebsocketClient] client
    def initialize(client = nil)
      @queue = Queue.new
      self.client = client unless client.nil?
      logger.info(LOG_NAME) { 'initialized' }
    end

    ##
    # @param [WebsocketClient] client
    def client=(client)
      @client = client.ws
      self.register_client_events
    end

    def register_client_events
      client.on :open do |event|
        self.start_queue_processing
      end
      client.on :close do |event|
        self.stop_queue_processing
      end
    end

    def start_queue_processing
      return unless @queue_thread.nil?

      logger.info(LOG_NAME) { 'started processing' }
      @queue_thread = Thread.new {
        loop do
          begin
            item = @queue.pop
            EM.next_tick {
              client.send(MessagePack.dump(item).bytes)
            }
          rescue => exc
            logger.error exc.message
          end
        end
      }
    end

    def stop_queue_processing
      if @queue_thread
        logger.info(LOG_NAME) { 'stopped processing' }
        @queue_thread.kill
        @queue_thread.join
        @queue_thread = nil
      end
    end

    def on_queue_push(event)
      logger.debug(LOG_NAME) { "queue push: #{event}" }
      if @queue.length > 1000
        logger.debug(LOG_NAME) { 'queue is over limit, popping item' }
        @queue.pop
      end
      @queue << event
    end
  end
end
