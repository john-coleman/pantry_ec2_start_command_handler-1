module Wonga
  module Daemon
    class PantryEc2StartCommandHandler
      def initialize(publisher, logger)
        @publisher = publisher
        @logger = logger
      end


      def handle_message(message)
        ec2 = AWS::EC2.new
        instance = ec2.instances[message['instance_id']]
        case instance.status
        when :stopped
          instance.start
          @logger.info("Instance #{message['instance_id']} start requested")
        when :terminated
          @logger.error
          return
        when :running
          @publisher.publish message
          @logger.info("Instance #{message['instance_id']} started")
          return
        end        
        raise "Instance #{message['instance_id']} still pending"
      end
    end
  end
end
