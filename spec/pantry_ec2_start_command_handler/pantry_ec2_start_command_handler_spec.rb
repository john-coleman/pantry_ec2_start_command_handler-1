require 'wonga/daemon/publisher'
require 'logger'
require_relative '../../pantry_ec2_start_command_handler/pantry_ec2_start_command_handler'

RSpec.describe Wonga::Daemon::PantryEc2StartCommandHandler do
  let(:publisher) { instance_double(Wonga::Daemon::Publisher) }
  let(:error_publisher) { instance_double(Wonga::Daemon::Publisher) }
  let(:logger) { instance_double(Logger).as_null_object }
  let(:ec2) { instance_double(AWS::EC2) }

  let(:message) do
    {
      'pantry_request_id' => 1,
      'instance_id' => 'i-f4819cb9',
      'instance_name' => 'some-hostname',
      'domain' => 'some-domain.tld'
    }
  end

  subject do
    described_class.new(publisher, error_publisher, logger)
  end

  it_behaves_like 'handler'

  describe '#handle_message' do
    before(:each) do
      allow(AWS::EC2).to receive(:new).and_return(ec2)
      allow(ec2).to receive(:instances).and_return('i-f4819cb9' => instance)
      allow(publisher).to receive(:publish)
    end

    context 'machine stopped' do
      let(:instance) { instance_double(AWS::EC2::Instance, status: :stopped, start: true, exists?: true) }

      it 'raises error' do
        expect { subject.handle_message(message) }.to raise_error
      end
    end

    context 'machine running' do
      let(:instance) { instance_double(AWS::EC2::Instance, status: :running, exists?: true) }

      it 'publish' do
        expect(publisher).to receive(:publish)
        subject.handle_message(message)
      end
    end

    context 'machine is terminated' do
      let(:instance) { instance_double(AWS::EC2::Instance, status: :terminated, exists?: true) }

      it 'sends message to error publisher' do
        expect(error_publisher).to receive(:publish)
        subject.handle_message(message)
      end
    end

    context 'machine does not exist' do
      let(:instance) { instance_double(AWS::EC2::Instance, exists?: false) }

      it 'sends message to error publisher' do
        expect(error_publisher).to receive(:publish)
        subject.handle_message(message)
      end
    end
  end
end
