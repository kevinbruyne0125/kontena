require_relative '../../spec_helper'

describe Kontena::WebsocketClient do

  let(:subject) { described_class.new('', '')}

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  around(:each) do |example|
    EM.run {
      example.run
      EM.stop
    }
  end

  describe '#on_message' do
    it 'calls subscribers when response message' do
      subscriber = spy
      received = false
      expect(subscriber).to receive(:on_message).once
      Kontena::Pubsub.subscribe('rpc_response:test') do |msg|
        received = true
        subscriber.on_message(msg)
      end
      event = double(:event, data: MessagePack.dump([1, 'test', nil, 'daa']).bytes)
      subject.on_message(double.as_null_object, event)
      EM.run_deferred_callbacks
      Timeout::timeout(1){ sleep 0.01 until received }
    end
  end

  describe '#connected?' do
    it 'returns false by default' do
      expect(subject.connected?).to eq(false)
    end

    it 'returns true if connection is established' do
      subject.on_open(spy(:event))
      expect(subject.connected?).to eq(true)
    end
  end
end
