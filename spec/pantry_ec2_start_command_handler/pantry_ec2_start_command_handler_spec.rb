require 'spec_helper'
require 'wonga/daemon/aws_resource'
require 'wonga/daemon/publisher'
require 'logger'
require_relative '../../pantry_ec2_start_command_handler/pantry_ec2_start_command_handler'

RSpec.describe Wonga::Daemon::PantryEc2StartCommandHandler do
  let(:logger) { instance_double(Logger).as_null_object }
  let(:publisher) { instance_double(Wonga::Daemon::Publisher) }
  let(:error_publisher) { instance_double(Wonga::Daemon::Publisher) }
  let(:aws_ec2_resource) { Aws::EC2::Resource.new }
  let(:aws_resource) { Wonga::Daemon::AWSResource.new(error_publisher, logger, aws_ec2_resource) }

  let(:request_id) { 2 }

  let(:message) do
    {
      'pantry_request_id' => request_id,
      'instance_id' => 'i-f4819cb9',
      'instance_name' => 'some-hostname',
      'domain' => 'some-domain.tld'
    }
  end
  let(:instance_attributes) do
    {
      instance_id: message['instance_id'],
      tags: [
        key: 'pantry_request_id',
        value: request_id.to_s
      ]
    }
  end
  let(:instance_response) { { reservations: [{ instances: [instance_attributes] }] } }
  let(:instance_state) { instance_double(Aws::EC2::Types::InstanceState, code: 80, name: 'stopped') }
  let(:instance_exists) { true }
  let(:instance) { instance_double(Aws::EC2::Instance, state: instance_state, exists?: instance_exists) }

  subject do
    described_class.new(publisher, error_publisher, logger, aws_resource)
  end

  it_behaves_like 'handler'

  describe '#handle_message' do
    before(:each) do
      aws_ec2_resource.client.stub_responses(:describe_instances, instance_response)
      allow(aws_resource).to receive(:find_server_by_id).with(message['instance_id']).and_return(instance)
      allow(publisher).to receive(:publish)
    end

    context 'machine stopped' do
      before(:each) do
        allow(instance).to receive(:start)
      end

      it 'starts machine' do
        expect(instance).to receive(:start)
        expect { subject.handle_message(message) }.to raise_error RuntimeError
      end
    end

    context 'machine running' do
      let(:instance_state) { instance_double(Aws::EC2::Types::InstanceState, code: 16, name: 'running') }
      let(:instance_exists) { true }

      it 'publish' do
        expect(publisher).to receive(:publish)
        subject.handle_message(message)
      end
    end

    context 'machine is terminated' do
      let(:instance_state) { instance_double(Aws::EC2::Types::InstanceState, code: 48, name: 'terminated') }
      let(:instance_exists) { true }

      it 'sends message to error publisher' do
        expect(error_publisher).to receive(:publish)
        subject.handle_message(message)
      end
    end

    context 'machine does not exist' do
      let(:instance_state) { instance_double(Aws::EC2::Types::InstanceState, code: 48, name: 'terminated') }
      let(:instance_exists) { false }

      it 'sends message to error publisher' do
        expect(error_publisher).to receive(:publish)
        subject.handle_message(message)
      end
    end
  end
end
