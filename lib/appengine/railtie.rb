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

require 'fileutils'


module AppEngine


  # == AppEngine Rails integration
  #
  # A Railtie providing Rails integration with the Google App Engine runtime
  # environment. Sets up the Rails logger to log to the Google Cloud Console
  # in production.
  #
  # To use, just include the "appengine" gem in your gemfile, and make sure
  # it is required in your config/application.rb (if you are not already
  # using Bundler.require).
  #
  # === Configuration
  #
  # The following configuration parameters are supported.
  #
  # [<tt>config.appengine.use_cloud_logger</tt>]
  #   Set to true to cause the Rails logger to log to Google Cloud Console.
  #   By default, this is true in the production environment and false in
  #   all other environments. You may override this setting in individual
  #   environment config files.
  #
  # [<tt>config.appengine.logfile</tt>]
  #   The path to the log file when <tt>use_cloud_logger</tt> is active.
  #   You should normally leave this as the default when deploying to Google
  #   App Engine, but you may set it to a different path if you want to test
  #   logging in a development environment.
  #
  # [<tt>config.appengine.trace_id_var</tt>]
  #   The name of a fiber-local variable to store the current request's trace
  #   ID. This is used to communicate request and trace information between
  #   Rack and the cloud logger. You may change it if you need to control
  #   fiber-local variable names.

  class Railtie < ::Rails::Railtie

    # :stopdoc:

    config.appengine = ::ActiveSupport::OrderedOptions.new

    config.appengine.use_cloud_logger = ::Rails.env.to_s == 'production'
    config.appengine.logfile = ::AppEngine::Logger::DEFAULT_LOG_FILENAME
    config.appengine.trace_id_var = ::AppEngine::Logger::DEFAULT_TRACE_ID_VAR


    initializer 'google.appengine.logger', before: :initialize_logger do |app|
      if app.config.appengine.use_cloud_logger
        app.config.logger = ::AppEngine::Logger.create(
            logfile: app.config.appengine.logfile,
            trace_id_var: app.config.appengine.trace_id_var)
        app.config.log_formatter = app.config.logger.formatter

        app.middleware.insert_before(::Rails::Rack::Logger,
            ::AppEngine::Logger::Middleware,
            logger: app.config.logger,
            trace_id_var: app.config.appengine.trace_id_var)
      end
    end

    # :startdoc:

  end


end
