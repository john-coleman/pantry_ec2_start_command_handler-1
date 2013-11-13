require 'spec_helper'
require_relative '../../pantry_ec2_start_command_handler/pantry_ec2_start_command_handler'

describe Wonga::Daemon::PantryEc2StartCommandHandler do
  let(:publisher) { instance_double('Wonga::Publisher').as_null_object }
  let(:logger) { instance_double('Logger').as_null_object }
  let(:instance) { instance_double('AWS::EC2::Instance').as_null_object }
  let(:ec2) { instance_double('AWS::EC2') }

  subject do 
    described_class.new(publisher, logger).as_null_object
  end
  
  it_behaves_like 'handler'

  describe "#handle_message" do
    before(:each) do
      AWS::EC2.stub(:new).and_return(ec2)
      ec2.stub(:instances).and_return(instance)
      publisher.stub(:publish)
    end

    context "machine stopped" do
      it "calls instance.start" do
        instance.stub(:status).and_return(:stopped)        
        instance.should_receive(:start).and_return(nil) # even on success returns nil
        subject.handle_message({"instance_id"=>"i-6c3db923"})
      end
    end

    context "machine pending" do 
      it "raises a benign error" do
        instance.stub(:status).and_return(:pending)        
        expect {
          subject.handle_message("instance_id"=>"i-6c3db923") 
        }.to raise_error
      end
    end

    context "machine running" do 
      it "should publish" do
        instance.stub(:status).and_return(:running)
        publisher.should_receive(:publish)        
        subject.handle_message({"instance_id"=>"i-6c3db923"})
      end
    end
  end
end