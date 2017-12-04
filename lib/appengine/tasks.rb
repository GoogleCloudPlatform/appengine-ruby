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
  # The command to be run may either be provided as a rake argument, or as
  # command line arguments, delimited by two dashes `--`. (The dashes are
  # needed to separate your command from rake arguments and flags.)
  # For example, to run a production database migration, you can run either of
  # the following equivalent commands:
  #
  #     bundle exec rake "appengine:exec[bundle exec bin/rails db:migrate]"
  #     bundle exec rake appengine:exec -- bundle exec bin/rails db:migrate
  #
  # To display usage instructions, provide two dashes but no command:
  #
  #     bundle exec rake appengine:exec --
  #
  # ### Parameters
  #
  # You may customize the behavior of App Engine execution through a few
  # enviroment variable parameters. These are set via the normal mechanism at
  # the end of a rake command line. For example, to set GAE_CONFIG:
  #
  #     bundle exec rake appengine:exec GAE_CONFIG=myservice.yaml -- bundle exec bin/rails db:migrate
  #
  # Be sure to set these parameters before the double dash. Any arguments
  # following the double dash are interpreted as part of the command itself.
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
  # Expressed as a string formatted like: "2h15m10s". Default is "10m".
  #
  module Tasks

    ## @private
    CONFIG_ENV = "GAE_CONFIG"
    ## @private
    SERVICE_ENV = "GAE_SERVICE"
    ## @private
    VERSION_ENV = "GAE_VERSION"
    ## @private
    TIMEOUT_ENV = "GAE_TIMEOUT"
    ## @private
    WRAPPER_IMAGE_ENV = "GAE_EXEC_WRAPPER_IMAGE"

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
          verify_gcloud_and_report_errors
          if args[:cmd]
            command = ::Shellwords.split args[:cmd]
          else
            i = (::ARGV.index{ |a| a.to_s == "--" } || -1) + 1
            if i == 0
              report_error <<-MESSAGE
No command provided for appengine:exec.
Did you remember to delimit it with two dashes? e.g.
  bundle exec rake appengine:exec -- bundle exec ruby myscript.rb
For detailed usage instructions, provide two dashes but no command:
  bundle exec rake appengine:exec --
              MESSAGE
            end
            command = ::ARGV[i..-1]
            if command.empty?
              show_usage
              exit
            end
          end
          app_exec = Exec.new \
              command,
              service: ::ENV[SERVICE_ENV],
              config_path: ::ENV[CONFIG_ENV],
              version: ::ENV[VERSION_ENV],
              timeout: ::ENV[TIMEOUT_ENV],
              wrapper_image: ::ENV[WRAPPER_IMAGE_ENV]
          start_and_report_errors app_exec
          exit
        end
      end

      def show_usage
        puts <<-USAGE
rake appengine:exec

This Rake task executes a given command in the context of an App Engine
application, using App Engine remote execution. For more information,
on this capability, see the AppEngine::Exec documentation at
http://www.rubydoc.info/gems/appengine/AppEngine/Exec

The command to be run may either be provided as a rake argument, or as
command line arguments delimited by two dashes `--`. (The dashes are
needed to separate your command from rake arguments and flags.)
For example, to run a production database migration, you can run either
of the following equivalent commands:

    bundle exec rake "appengine:exec[bundle exec bin/rails db:migrate]"
    bundle exec rake appengine:exec -- bundle exec bin/rails db:migrate

To display these usage instructions, provide two dashes but no command:

    bundle exec rake appengine:exec --

You may customize the behavior of App Engine execution through a few
enviroment variable parameters. These are set via the normal mechanism at
the end of a rake command line. For example, to set GAE_CONFIG:

    bundle exec rake appengine:exec GAE_CONFIG=myservice.yaml -- bundle exec bin/rails db:migrate

Be sure to set these parameters before the double dash. Any arguments
following the double dash are interpreted as part of the command itself.

The following environment variable parameters are supported:

GAE_CONFIG

  Path to the App Engine config file, used when your app has multiple
  services, or the config file is otherwise not called `./app.yaml`. The
  config file is used to determine the name of the App Engine service.

GAE_SERVICE

  Name of the service to be used. If both `GAE_CONFIG` and `GAE_SERVICE`
  are provided and imply different service names, an error will be raised.

GAE_VERSION

  The version of the service, used to identify which application image to
  use to run your command. If not specified, uses the most recently created
  version, regardless of whether that version is actually serving traffic.

GAE_TIMEOUT

  Amount of time to wait before appengine:exec terminates the command.
  Expressed as a string formatted like: "2h15m10s". Default is "10m".

This rake task is provided by the "appengine" gem. To make these tasks
available, add the following line to your Rakefile:

    require "appengine/tasks"

If your app uses Ruby on Rails, the gem provides a railtie that adds its
tasks automatically, so you don't have to do anything beyond adding the
gem to your Gemfile.

For more information or to report issues, visit the Github page:
https://github.com/GoogleCloudPlatform/appengine-ruby
        USAGE
      end

      def verify_gcloud_and_report_errors
        Util::Gcloud.verify!
      rescue Util::Gcloud::BinaryNotFound
        report_error <<-MESSAGE
Could not find the `gcloud` binary in your system path.
This tool requires the Google Cloud SDK. To download and install it,
visit https://cloud.google.com/sdk/downloads
        MESSAGE
      rescue Util::Gcloud::GcloudNotAuthenticated
        report_error <<-MESSAGE
The gcloud authorization has not been completed. If you have not yet
initialized the Google Cloud SDK, we recommend running the `gcloud init`
command as described at https://cloud.google.com/sdk/docs/initializing
Alternately, you may log in directly by running `gcloud auth login`.
        MESSAGE
      rescue Util::Gcloud::ProjectNotSet
        report_error <<-MESSAGE
The gcloud project configuration has not been set. If you have not yet
initialized the Google Cloud SDK, we recommend running the `gcloud init`
command as described at https://cloud.google.com/sdk/docs/initializing
Alternately, you may set the default project configuration directly by
running `gcloud config set project <project-name>`.
        MESSAGE
      end

      def start_and_report_errors app_exec
        app_exec.start
      rescue Exec::ConfigFileNotFound => ex
        report_error <<-MESSAGE
Could not determine which service should run this command because the App
Engine config file "#{ex.config_path}" was not found.
Specify the config file using the GAE_CONFIG argument. e.g.
  bundle exec rake appengine:exec GAE_CONFIG=myapp.yaml -- myscript.sh
Alternately, you may specify a service name directly with GAE_SERVICE. e.g.
  bundle exec rake appengine:exec GAE_SERVICE=myservice -- myscript.sh
MESSAGE
      rescue Exec::BadConfigFileFormat => ex
        report_error <<-MESSAGE
Could not determine which service should run this command because the App
Engine config file "#{ex.config_path}" was malformed.
It must be a valid YAML file.
Specify the config file using the GAE_CONFIG argument. e.g.
  bundle exec rake appengine:exec GAE_CONFIG=myapp.yaml -- myscript.sh
Alternately, you may specify a service name directly with GAE_SERVICE. e.g.
  bundle exec rake appengine:exec GAE_SERVICE=myservice -- myscript.sh
MESSAGE
      rescue Exec::NoSuchVersion => ex
        if ex.version
          report_error <<-MESSAGE
Could not find version "#{ex.version}" of service "#{ex.service}".
Please double-check the version exists. To use the most recent version by
default, omit the GAE_VERSION argument.
MESSAGE
        else
          report_error <<-MESSAGE
Could not find any versions of service "#{ex.service}".
Please double-check that you have deployed this service. If you want to run
a command against a different service, you may provide a GAE_CONFIG argument
pointing to your App Engine config file, or a GAE_SERVICE argument to specify
a service directly.
MESSAGE
        end
      rescue Exec::ServiceNameConflict => ex
        report_error <<-MESSAGE
The explicit service name "#{ex.service_name}" was requested
but conflicts with the service "#{ex.config_name}" from the
config file "#{ex.config_path}"
You should specify either GAE_SERVICE or GAE_CONFIG but not both.
MESSAGE
      end

      def report_error str
        ::STDERR.puts str
        exit 1
      end

    end

  end
end


::AppEngine::Tasks.define
