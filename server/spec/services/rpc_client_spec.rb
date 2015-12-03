require_relative '../spec_helper'

describe RpcClient do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }
  let(:node_id) { SecureRandom.hex(32) }
  let(:subject) { RpcClient.new(node_id, 1) }
  let(:channel) { RpcClient::RPC_CHANNEL }

  def publish_response(id, response)
    MongoPubsub.publish(channel, {message: [1, id, nil, response]})
  end

  def publish_error(id, error)
    MongoPubsub.publish(channel, {message: [1, id, error, nil]})
  end

  def fake_server(type = 'request')
    MongoPubsub.subscribe(channel) do |resp|
      if resp['type'] == type
        yield(resp)
      end
    end
  end

  describe '#request' do
    it 'returns a result from rpc server' do
      server = fake_server {|resp|
        response = resp['message'][3]
        response.unshift(resp['message'][2])
        publish_response(resp['message'][1], response)
      }
      resp = subject.request('/hello/service', :foo, :bar)
      expect(resp).to eq(['/hello/service', :foo, :bar])

      server.terminate
    end

    it 'raises error from rpc server' do
      server = fake_server {|resp|
        response = resp['message'][3]
        response.unshift(resp['message'][2])
        publish_error(resp['message'][1], 'error!')
      }
      expect {
        subject.request('/hello/service', :foo, :bar)
      }.to raise_error(RpcClient::Error)

      server.terminate
    end
  end

  describe '#notify' do
    it 'sends notification to server' do
      receiver = spy(:receiver)
      server = fake_server('notify') {|resp|
        receiver.handle(resp['message'][2])
      }
      expect(receiver).to receive(:handle).with([:foo, :bar])
      subject.notify('/hello/service', :foo, :bar)
      sleep 0.05
      server.terminate
    end
  end
end
