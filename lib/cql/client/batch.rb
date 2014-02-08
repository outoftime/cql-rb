# encoding: utf-8

module Cql
  module Client
    # @private
    class AsynchronousBatch < Batch
      def initialize(type, execute_options_decoder, connection_manager, options={})
        raise ArgumentError, "Unknown batch type: #{type}" unless BATCH_TYPES.include?(type)
        @type = type
        @execute_options_decoder = execute_options_decoder
        @connection_manager = connection_manager
        @options = options
        @request_runner = RequestRunner.new
        @parts = []
      end

      def add(*args)
        @parts << args
        nil
      end

      def execute(options={})
        if options.is_a?(Symbol)
          options = @options.merge(consistency: options)
        else
          options = @options.merge(options)
        end
        options = @execute_options_decoder.decode_options(options)
        connection = nil
        attempts = 0
        begin
          connection = @connection_manager.random_connection
          request = Protocol::BatchRequest.new(BATCH_TYPES[@type], options[:consistency], options[:trace])
          @parts.each do |cql_or_statement, *bound_args|
            if cql_or_statement.is_a?(String)
              request.add_query(cql_or_statement, bound_args)
            else
              cql_or_statement.add_to_batch(request, connection, bound_args)
            end
          end
        rescue NotPreparedError
          attempts += 1
          if attempts < 3
            retry
          else
            raise
          end
        end
        @request_runner.execute(connection, request, options[:timeout])
      end

      private

      BATCH_TYPES = {
        :logged => Protocol::BatchRequest::LOGGED_TYPE,
        :unlogged => Protocol::BatchRequest::UNLOGGED_TYPE,
        :counter => Protocol::BatchRequest::COUNTER_TYPE,
      }.freeze
    end

    # @private
    class SynchronousBatch < Batch
      include SynchronousBacktrace

      def initialize(asynchronous_batch)
        @asynchronous_batch = asynchronous_batch
      end

      def add(*args)
        @asynchronous_batch.add(*args)
      end

      def execute(options={})
        synchronous_backtrace { @asynchronous_batch.execute(options).value }
      end
    end

    # @private
    class AsynchronousPreparedStatementBatch < PreparedStatementBatch
      def initialize(prepared_statement, batch)
        @prepared_statement = prepared_statement
        @batch = batch
      end

      def add(*args)
        @batch.add(@prepared_statement, *args)
      end

      def execute(options={})
        @batch.execute(options)
      end
    end

    # @private
    class SynchronousPreparedStatementBatch < PreparedStatementBatch
      include SynchronousBacktrace

      def initialize(asynchronous_batch)
        @asynchronous_batch = asynchronous_batch
      end

      def add(*args)
        @asynchronous_batch.add(*args)
      end

      def execute(options={})
        synchronous_backtrace { @asynchronous_batch.execute(options).value }
      end
    end
  end
end