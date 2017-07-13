# Copyright 2017 Google Inc. All rights reserved.
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

# This file should be loaded or required from a Rakefile to define AppEngine
# related tasks.

require "shellwords"

require "appengine/util/gcloud"
require "appengine/exec"


module AppEngine

  ##
  # # App Engine Rake Tasks.
  #
  # To make these tasks available, add the line `require "appengine/tasks"`
  # to your Rakefile. If your app uses Ruby on Rails, then the appengine gem
  # provides a railtie that adds its tasks automatically, so you don't have
  # to do anything beyond adding the gem to your Gemfile.
  #
  # The following tasks are defined:
  #
  # ## Rake appengine:exec
  #
  # Executes a given command in the context of an App Engine application, using
  # App Engine remote execution. See {AppEngine::Exec} for more information on
  # this capability.
  #
  # The command to be run may be provided as a rake argument, or as command
  # line arguments, delimited by two dashes `--`. (The dashes are needed to
  # separate your command from rake arguments and flags.)
  # For example, to run a production database migration, you can run either of
  # the following equivalent commands:
  #
  #    bundle exec rake "appengine:exec[bundle exec rake db:migrate]"
  #    bundle exec rake appengine:exec -- bundle exec rake db:migrate
  #
  # ### Parameters
  #
  # You may customize the behavior of App Engine execution through a few
  # enviroment variable parameters. These are set via the normal mechanism at
  # the end of a rake command line. For example, to set GAE_CONFIG:
  #
  #     bundle exec rake appengine:exec -- bundle exec rake db:migrate GAE_CONFIG=myservice.yaml
  #
  # The following environment variable parameters are supported:
  #
  # #### GAE_CONFIG
  #
  # Path to the App Engine config file, used when your app has multiple
  # services, or the config file is otherwise not called `./app.yaml`. The
  # config file is used to determine the name of the App Engine service.
  #
  # #### GAE_SERVICE
  #
  # Name of the service to be used. If both `GAE_CONFIG` and `GAE_SERVICE` are
  # provided and imply different service names, an error will be raised.
  #
  # #### GAE_VERSION
  #
  # The version of the service, used to identify which application image to
  # use to run your command. If not specified, uses the most recently created
  # version, regardless of whether that version is actually serving traffic.
  #
  # #### GAE_TIMEOUT
  #
  # Amount of time to wait before appengine:exec terminates the command.
  # Expressed as a string formatted like: "2h15m10s". Default is "15m".
  #
  module Tasks

    CONFIG_ENV = "GAE_CONFIG"
    SERVICE_ENV = "GAE_SERVICE"
    VERSION_ENV = "GAE_VERSION"
    TIMEOUT_ENV = "GAE_TIMEOUT"

    @defined = false

    class << self

      ##
      # @private
      # Define rake tasks.
      #
      def define
        if @defined
          puts "AppEngine rake tasks already defined."
          return
        end
        @defined = true

        setup_exec_task
      end

      private

      def setup_exec_task
        ::Rake.application.last_description =
            "Execute the given command in Google App Engine."
        ::Rake::Task.define_task "appengine:exec", [:cmd] do |t, args|
          Util::Gcloud.verify!
          if args[:cmd]
            command = ::Shellwords.split args[:cmd]
          else
            i = (::ARGV.index{ |a| a.to_s == "--" } || -1) + 1
            if i == 0
              raise "No command provided for appengine:exec." \
                " Did you remember to delimit it with two dashes? e.g." \
                " `rake appengine:exec -- bundle exec ruby myscript.rb`"
            end
            command = ::ARGV[i..-1]
          end
          app_exec = Exec.new \
              command,
              service: ::ENV[SERVICE_ENV],
              config_path: ::ENV[CONFIG_ENV],
              version: ::ENV[VERSION_ENV],
              timeout: ::ENV[TIMEOUT_ENV]
          app_exec.start
          exit
        end
      end

    end

  end
end


::AppEngine::Tasks.define
