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

require 'minitest/autorun'
require 'appengine'


module AppEngine
  module Tests  # :nodoc:

    class TestFormatter < ::Minitest::Test  # :nodoc:


      def setup
        @time_sec = 1461544128
        @time_nsec = 580791000
        @time = ::Time.at(@time_sec, @time_nsec / 1000)
        @trace_id = 'a1b2c3d4e5f6'
        ::Thread.current[::AppEngine::Logger::DEFAULT_TRACE_ID_VAR] = @trace_id
        @formatter = ::AppEngine::Logger::Formatter.new
      end


      def test_format_empty
        result = @formatter.call('ERROR', @time, 'prog', '')
        assert_equal('', result)
      end


      def test_format_with_progname
        result = @formatter.call('ERROR', @time, 'prog', 'this message')
        assert_equal(
            "{\"message\":\"prog: this message\"," +
              "\"timestamp\":{\"seconds\":#{@time_sec},\"nanos\":#{@time_nsec}}," +
              "\"severity\":\"ERROR\"," +
              "\"traceId\":\"#{@trace_id}\"}\n",
            result)
      end


      def test_format_with_no_trace_id
        ::Thread.current[::AppEngine::Logger::DEFAULT_TRACE_ID_VAR] = nil
        result = @formatter.call('ERROR', @time, '', 'this message')
        assert_equal(
            "{\"message\":\"this message\"," +
              "\"timestamp\":{\"seconds\":#{@time_sec},\"nanos\":#{@time_nsec}}," +
              "\"severity\":\"ERROR\"}\n",
            result)
      end


      def test_format_with_warning_severity
        result = @formatter.call('WARN', @time, '', 'this message')
        assert_equal(
            "{\"message\":\"this message\"," +
              "\"timestamp\":{\"seconds\":#{@time_sec},\"nanos\":#{@time_nsec}}," +
              "\"severity\":\"WARNING\"," +
              "\"traceId\":\"#{@trace_id}\"}\n",
            result)
      end


      def test_format_with_critical_severity
        result = @formatter.call('FATAL', @time, '', 'this message')
        assert_equal(
            "{\"message\":\"this message\"," +
              "\"timestamp\":{\"seconds\":#{@time_sec},\"nanos\":#{@time_nsec}}," +
              "\"severity\":\"CRITICAL\"," +
              "\"traceId\":\"#{@trace_id}\"}\n",
            result)
      end


      def test_format_with_unknown_severity
        result = @formatter.call('UNKNOWN', @time, '', 'this message')
        assert_equal(
            "{\"message\":\"this message\"," +
              "\"timestamp\":{\"seconds\":#{@time_sec},\"nanos\":#{@time_nsec}}," +
              "\"severity\":\"CRITICAL\"," +
              "\"traceId\":\"#{@trace_id}\"}\n",
            result)
      end


    end


    class TestLogger < ::Minitest::Test  # :nodoc:


      def test_no_logging
        lines = run_test do |logger|
        end
        assert_equal([], lines)
      end


      def test_basic_log
        trace_id = "tracetrace"
        lines = run_test(trace_id) do |logger|
          logger.progname = "rails"
          logger.info("Hello")
          logger.warn("This is a warning")
        end
        assert_equal(2, lines.size)
        assert_log_entry("rails: Hello", "INFO", trace_id, lines[0])
        assert_log_entry("rails: This is a warning", "WARNING", trace_id, lines[1])
      end


      def assert_log_entry(expected_message, expected_severity, expected_trace_id, line)
        if line =~ /^\{"message":"(.*)","timestamp":\{"seconds":\d+,"nanos":\d+\},"severity":"(\w+)"(,"traceId":"(\w+)")?\}\n$/
          message = $1
          severity = $2
          trace_id = $4
          assert_equal(expected_message, message)
          assert_equal(expected_severity, severity)
          assert_equal(expected_trace_id, trace_id)
        else
          flunk("Bad format: #{line.inspect}")
        end
      end


      def run_test(trace_id=nil)
        stringio = ::StringIO.new('', 'w')
        app = ::Proc.new { |env|
          yield(env['rack.logger'])
        }
        middleware = ::AppEngine::Logger::Middleware.new(app, logfile: stringio)
        middleware.call({'HTTP_X_CLOUD_TRACE_CONTEXT' => trace_id})
        ::StringIO.new(stringio.string).each_line.to_a
      end


    end

  end
end
