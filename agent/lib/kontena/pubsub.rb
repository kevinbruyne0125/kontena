module Kontena
  class Pubsub

    class Subscription
      include Celluloid

      finalizer :cleanup
      attr_reader :channel

      # @param [String] channel
      # @param [Proc] block
      def initialize(channel, block)
        @channel = channel
        @block = block
        @queue = []
        async.process
      end

      # @param [Object] msg
      def push(msg)
        @queue << msg
      end

      private

      def process
        sleep 0.001
        @process = true
        while @process
          msg = @queue.shift
          send_message(msg) if msg
          sleep 0.001
        end
        @queue.clear
      end

      # @param [Object] msg
      def send_message(msg)
        @block.call(msg)
      end

      def cleanup
        @process = false
      end
    end

    # @return [Array<Subscription>]
    def self.subscriptions
      @subscriptions ||= []
    end

    # @param [String] channel
    # @return [Subscription]
    def self.subscribe(channel, &block)
      subscription = Subscription.new(channel, block)
      subscriptions << subscription

      subscription
    end

    # @param [Subscription]
    def self.unsubscribe(subscription)
      subscription.terminate if subscription.alive?
      subscriptions.delete(subscription)
    end

    # @param [String] channel
    # @param [Object] msg
    def self.publish(channel, msg)
      receivers = subscriptions.select{|s|
        begin
          s.alive? && s.channel == channel
        rescue Celluloid::DeadActorError
          unsubscribe(s)
        end
      }
      receivers.each do |subscription|
        begin
          subscription.async.push(msg)
        rescue
          unsubscribe(subscription)
        end
      end
    end

    def self.clear!
      subscriptions.each do |sub|
        unsubscribe(sub)
      end
    end
  end
end
