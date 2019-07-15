# frozen_string_literal: true

# Copyright 2019 Google LLC
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


module AppEngine
  ##
  # # AppEngine Rails integration
  #
  # A Railtie providing Rails integration with the Google App Engine runtime
  # environment.
  #
  # Specifically:
  #
  # * It installs the Stackdriver instrumentation, providing application
  #   diagnostics to the project's Stackdriver account.
  # * It installs the rake tasks, providing the ability to execute commands
  #   on demand in the production App Engine environment.
  #
  # To use, just include the "appengine" gem in your gemfile, and make sure
  # it is required in your config/application.rb (if you are not already
  # using Bundler.require).
  #
  # ## Configuration
  #
  # You may selectively deactivate features of this Railtie using Rails
  # configuration keys. For example, to disable rake tasks, include the
  # following line in one of your Rails configuration files:
  #
  #     config.appengine.define_tasks = false
  #
  # The following configuration keys are supported. Additional keys specific
  # to the various Stackdriver services may be defined in the individual
  # libraries.
  #
  # ### appengine.define_tasks
  #
  # Causes rake tasks to be added to the application. Default is true. Set it
  # to false to disable App Engine rake tasks.
  #
  # ### google_cloud.use_logging
  #
  # Activates Stackdriver Logging, collecting Rails logs so they appear on
  # the Google Cloud console. Default is true. Set it to false to disable
  # logging instrumentation.
  #
  # ### google_cloud.use_error_reporting
  #
  # Activates Stackdriver Error Reporting, collecting exceptions so they appear
  # on the Google Cloud console. Default is true. Set it to false to disable
  # error instrumentation.
  #
  # ### google_cloud.use_trace
  #
  # Activates Stackdriver Trace instrumentation, collecting application latency
  # trace data so it appears on the Google Cloud conosle. Default is true. Set
  # it to false to disable trace instrumentation.
  #
  # ### google_cloud.use_debugger
  #
  # Enables the Stackdriver Debugger. Default is true. Set it to false to
  # disable debugging.
  #
  class Railtie < ::Rails::Railtie
    config.appengine = ::ActiveSupport::OrderedOptions.new
    config.appengine.define_tasks = true

    rake_tasks do |app|
      require "appengine/tasks" if app.config.appengine.define_tasks
    end
  end
end
