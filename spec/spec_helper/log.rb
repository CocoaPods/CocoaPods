module SpecHelper
  module Log
    def log!
      puts
      logger = Object.new
      def logger.debug(msg); puts msg; end
      Executioner.logger = logger
    end

    def self.extended(context)
      context.after do
        Executioner.logger = nil
      end
    end
  end
end
