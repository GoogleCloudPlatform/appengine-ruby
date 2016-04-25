# Copyright 2016 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
;

require 'json'
require 'logger'


module AppEngine


  # == AppEngine Logger integration
  #
  # A collection of tools for talking to the StackDriver logs in the Google
  # Cloud Console.
  #
  # For logs to appear in the Google Cloud Console, they must be written in
  # JSON format to files matching the pattern "/var/log/app_engine/app*.json".
  # We provide an appropriate formatter, and a LogDevice that omits the
  # log header line.
  #
  # Logs should also be annotated with the request's Trace ID. We provide
  # a Rack Middleware to extract that ID from the environment and annotate
  # log entries. It uses a fiber-local variable to store the Trace ID for
  # the current request being handled by that fiber.

  module Logger


    # The name of a fiber-local variable storing the trace ID for the current
    # request.
    DEFAULT_TRACE_ID_VAR = :_google_appengine_trace_id

    # The default path to the log file.
    DEFAULT_LOG_FILENAME = '/var/log/app_engine/app-ruby.json'

    # A map from Ruby severity names to Google Cloud severity names.
    SEV_MAP = {
      'DEBUG' => 'DEBUG',
      'INFO' => 'INFO',
      'WARN' => 'WARNING',
      'ERROR' => 'ERROR',
      'FATAL' => 'CRITICAL'
    }


    # == AppEngie Formatter
    #
    # A formatter that generates the appropriate JSON format for log entries.
    # Pulls the trace ID from the fiber-local variable, if present.
    #
    # (see ::Logger::Formatter)

    class Formatter


      # Create a new formatter. You may optionally override the fiber-local
      # variable name used for the trace ID.

      def initialize(trace_id_var: DEFAULT_TRACE_ID_VAR)
        @trace_id_var = trace_id_var
      end


      def call(severity, time, progname, msg)  # :nodoc:
        msg = msg.to_s
        return '' if msg.empty?
        entry = {
          message: (progname.to_s != '') ? "#{progname}: #{msg}" : msg,
          timestamp: {seconds: time.to_i, nanos: time.nsec},
          severity: SEV_MAP.fetch(severity.to_s, 'CRITICAL')
        }
        trace_id = ::Thread.current[@trace_id_var]
        if trace_id
          entry[:traceId] = trace_id.to_s
        end
        ::JSON.generate(entry) + "\n"
      end

    end


    # == AppEngine LogDevice
    #
    # A ::Logger::LogDevice subclass that omits the log header line.

    class LogDevice < ::Logger::LogDevice

      def add_log_header(file)  # :nodoc:
      end

    end


    # == Rack Middleware for AppEngine logger
    #
    # A Rack middleware that sets the logger in the Rack environment, and
    # stashes the trace ID for the current request in a fiber-local variable
    # for the logger to use when formatting log entries.
    #
    # In a standard Rack application, you should use this middleware instead
    # of the standard ::Rack::Logger.

    class Middleware


      # Create a new AppEngine logging Middleware.
      # The argument is an options hash supporting the following keys:
      #
      # [<tt>:logger</tt>]
      #   A global logger to use. This should generally be a logger created
      #   by AppEngine::Logger.create(). The middleware sets env["rack.logger"]
      #   accordingly. If omitted, a default logger is created automatically
      #   when the middleware is constructed.
      # [<tt>:trace_id_var</tt>]
      #   The name of the fiber-local variable to use to stack the trace ID.
      #   Defaults to the value of DEFAULT_TRACE_ID_VAR. You generally should
      #   not need to modify this value unless you need to control fiber-local
      #   variable names.
      # [<tt>:logfile</tt>]
      #   If you do not specify a <tt>:logger</tt>, a logger is created that
      #   opens this file. Defaults to the value of DEFAULT_LOG_FILENAME.
      #   Generally, you should leave this setting to the default for
      #   deployments, because App Engine expects log files in a particular
      #   location. However, if you want to test log generation into a
      #   different directory in development, you may set it here.

      def initialize(app,
            logger: nil,
            trace_id_var: DEFAULT_TRACE_ID_VAR,
            logfile: DEFAULT_LOG_FILENAME)
        @app = app
        @trace_id_var = trace_id_var
        @logger = logger || Logger.create(trace_id_var: trace_id_var, logfile: logfile)
      end


      def call(env)  # :nodoc:
        env['rack.logger'] = @logger
        ::Thread.current[@trace_id_var] = Env.extract_trace_id(env)
        begin
          @app.call(env)
        ensure
          ::Thread.current[@trace_id_var] = nil
        end
      end

    end


    # Creates a new logger for AppEngine that writes to the correct location
    # using the correct formatting.
    # The argument is an options hash supporting the following keys:
    #
    # [<tt>:trace_id_var</tt>]
    #   The name of the fiber-local variable to use to stack the trace ID.
    #   Defaults to the value of DEFAULT_TRACE_ID_VAR. You generally should
    #   not need to modify this value unless you need to control fiber-local
    #   variable names.
    # [<tt>:logfile</tt>]
    #   Log file to write to. Defaults to the value of DEFAULT_LOG_FILENAME.
    #   Generally, you should leave this setting to the default for
    #   deployments, because App Engine expects log files in a particular
    #   location. However, if you want to test log generation into a
    #   different directory in development, you may set it here.

    def self.create(trace_id_var: DEFAULT_TRACE_ID_VAR, logfile: DEFAULT_LOG_FILENAME)
      if logfile.kind_of?(::String)
        ::FileUtils.mkdir_p(::File.dirname(logfile))
      end
      logger = ::Logger.new(LogDevice.new(logfile))
      logger.formatter = Formatter.new(trace_id_var: trace_id_var)
      logger
    end

  end
end
