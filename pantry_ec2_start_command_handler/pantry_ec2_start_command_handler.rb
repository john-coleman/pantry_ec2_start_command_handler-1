module Wonga
  module Daemon
    class PantryEc2StartCommandHandler
      def initialize(publisher, error_publisher, logger)
        @publisher = publisher
        @error_publisher = error_publisher
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
          send_error_message(message)
          return
        when :running
          @publisher.publish message
          @logger.info("Instance #{message['instance_id']} started")
          return
        end
        fail "Instance #{message['instance_id']} still pending"
      end

      def send_error_message(message)
        @logger.info 'Send request to cleanup an instance'
        @error_publisher.publish(message)
      end
    end
  end
end
