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

require "yaml"
require "json"
require "shellwords"
require "tempfile"

require "appengine/util/gcloud"


module AppEngine

  ##
  # # App Engine remote execution
  #
  # This class provides a client for App Engine remote execution, allowing
  # App Engine applications to perform on-demand tasks in the App Engine
  # environment. This may be used for safe running of ops and maintenance
  # tasks, such as database migrations, that access production cloud resources.
  #
  # ## About App Engine execution
  #
  # App Engine execution spins up an image of a deployed App Engine app, and
  # runs a command in that image. For example, if your app runs on Ruby on
  # Rails, then your app provides a `bin/rails` tool, and you may invoke it
  # using App Engine execution---for example to run a command such as
  # `bundle exec bin/rails db:migrate` in the image.
  #
  # When App Engine execution runs your command, it provides access to key
  # elements of the App Engine environment, including:
  #
  # * The same runtime that runs your application in App Engine itself.
  # * Any Cloud SQL connections requested by your application.
  # * Any environment variables set by your application.
  #
  # The command runs on virtual machines provided by Google Cloud Container
  # Builder, and has access to the credentials of the Cloud Container Builder
  # service account.
  #
  # ## Prerequisites
  #
  # To use App Engine remote execution, you will need:
  #
  # * An app deployed to Google App Engine, of course!
  # * The gcloud SDK installed and configured. See https://cloud.google.com/sdk/
  # * The `appengine` gem.
  #
  # You may also need to grant the Cloud Container Builder service account
  # any permissions needed by your command. Often, Project Editor permissions
  # will be sufficient for most tasks. You can find the service account
  # configuration in the IAM tab in the Cloud Console under the name
  # `[your-project-number]@cloudbuild.gserviceaccount.com`.
  #
  # You may use the `AppEngine::Exec` class to run commands directly. However,
  # in most cases, it will be easier to run commands via the provided rake
  # tasks. See {AppEngine::Tasks} for more info.
  #
  # ## Configuring
  #
  # This class uses three parameters to specify which application image to use
  # to run your command: `service`, `config_path`, and `version`.
  #
  # In most cases, you can use the defaults. The Exec class will look in your
  # current directory for a file called `./app.yaml` which describes your App
  # Engine service. It gets the service name from this file (or uses the
  # "default" name if none is specified), then looks up the most recently
  # created deployment version for that service. That deployment version then
  # provides the application image that runs your command.
  #
  # If your app has multiple services, you may specify which config file
  # (other than `./app.yaml`) describes the desired service, by providing the
  # `config_path` parameter. Alternately, you may specify a service name
  # directly by providing the `service` parameter. If you provide both
  # parameters, `service` takes precedence.
  #
  # Usually, App Engine execution uses the image for the most recently created
  # version of the service. (Note: the most recently created version is used,
  # regardless of whether that version is currently receiving traffic.) If you
  # want to use the image for a different version, you may specify a version
  # by providing the `version` parameter.
  #
  # You may also provide a timeout, which is the length of time that App
  # Engine execution will allow your command to run before it is considered to
  # have stalled and is terminated. The timeout should be a string of the form
  # `2h15m10s`. The default is `10m`.
  #
  # ## Resource usage and billing
  #
  # App Engine remote execution uses virtual machine resources provided by
  # Google Cloud Container Builder. Generally, a certain number of usage
  # minutes per day is covered under a free tier, but additional compute usage
  # beyond that time is billed to your Google Cloud account. For more details,
  # see https://cloud.google.com/container-builder/pricing
  #
  # If your command makes API calls or utilizes other cloud resources, you may
  # also be billed for that usage. However, remote execution does not use
  # actual App Engine instances, and you will not be billed for additional App
  # Engine instance usage.
  #
  class Exec

    @default_timeout = "10m".freeze
    @default_service = "default".freeze
    @default_config_path = "./app.yaml".freeze
    @default_wrapper_image = "gcr.io/google-appengine/exec-wrapper:latest".freeze


    ##
    # Base class for exec-related usage errors.
    #
    class UsageError < ::StandardError
    end


    ##
    # Exception raised when the App Engine config file could not be found.
    #
    class ConfigFileNotFound < UsageError
      def initialize config_path
        @config_path = config_path
        super "Config file #{config_path} not found."
      end
      attr_reader :config_path
    end

    ##
    # Exception raised when the App Engine config file could not be parsed.
    #
    class BadConfigFileFormat < UsageError
      def initialize config_path
        @config_path = config_path
        super "Config file #{config_path} malformed."
      end
      attr_reader :config_path
    end

    ##
    # Exception raised when the given version could not be found, or no
    # versions at all could be found for the given service.
    #
    class NoSuchVersion < UsageError
      def initialize service, version=nil
        @service = service
        @version = version
        if version
          super "No such version \"#{version}\" for service \"#{service}\""
        else
          super "No versions found for service \"#{service}\""
        end
      end
      attr_reader :service
      attr_reader :version
    end

    ##
    # Exception raised when an explicitly-specified service name conflicts with
    # a config-specified service name.
    #
    class ServiceNameConflict < UsageError
      def initialize service_name, config_name, config_path
        @service_name = service_name
        @config_name = config_name
        @config_path = config_path
        super "Service name conflicts with config file"
      end
      attr_reader :service_name
      attr_reader :config_name
      attr_reader :config_path
    end


    class << self

      ## @return [String] Default command timeout.
      attr_accessor :default_timeout

      ## @return [String] Default service name if the config doesn't specify.
      attr_accessor :default_service

      ## @return [String] Path to default config file.
      attr_accessor :default_config_path

      ## @return [String] Docker image that implements the app engine wrapper.
      attr_accessor :default_wrapper_image

      ##
      # Create an execution for a rake task.
      #
      # @param name [String] Name of the task
      # @param args [Array<String>] Args to pass to the task
      # @param env_args [Array<String>] Environment variable settings, each
      #     of the form `NAME=value`.
      # @param service [String,nil] Name of the service. If omitted, obtains
      #     the service name from the config file.
      # @param config_path [String,nil] App Engine config file to get the
      #     service name from if the service name is not provided directly.
      #     Defaults to the value of `AppEngine::Exec.default_config_path`.
      # @param version [String,nil] Version string. Defaults to the most
      #     recently created version of the given service (which may not be the
      #     one currently receiving traffic).
      # @param timeout [String,nil] Timeout string. Defaults to the value of
      #     `AppEngine::Exec.default_timeout`.
      #
      def new_rake_task name, args: [], env_args: [],
                        service: nil, config_path: nil, version: nil,
                        timeout: nil
        escaped_args = args.map{ |arg|
          arg.gsub(/[,\[\]]/){ |m| "\\#{m}" }
        }
        if escaped_args.empty?
          name_with_args = name
        else
          name_with_args = "#{name}[#{escaped_args.join ','}]"
        end
        new ["bundle", "exec", "rake", name_with_args] + env_args,
            service: service, config_path: config_path, version: version,
            timeout: timeout
      end

    end


    ##
    # Create an execution for the given command.
    #
    # @param command [Array<String>] The command in array form.
    # @param service [String,nil] Name of the service. If omitted, obtains
    #     the service name from the config file.
    # @param config_path [String,nil] App Engine config file to get the
    #     service name from if the service name is not provided directly.
    #     Defaults to the value of `AppEngine::Exec.default_config_path`.
    # @param version [String,nil] Version string. Defaults to the most
    #     recently created version of the given service (which may not be the
    #     one currently receiving traffic).
    # @param timeout [String,nil] Timeout string. Defaults to the value of
    #     `AppEngine::Exec.default_timeout`.
    #
    def initialize command,
                   service: nil, config_path: nil, version: nil, timeout: nil,
                   wrapper_image: nil
      @command = command
      @service = service
      @config_path = config_path
      @version = version
      @timeout = timeout
      @wrapper_image = wrapper_image

      yield self if block_given?
    end


    ## @return [String,nil] The service name, or nil to read from the config.
    attr_accessor :service

    ## @return [String,nil] Path to the config file, or nil to use the default.
    attr_accessor :config_path

    ## @return [String,nil] Service version, or nil to use the most recent.
    attr_accessor :version

    ## @return [String,nil] Command timeout, or nil to use the default.
    attr_accessor :timeout

    ## @return [String,Array<String>] Command to run.
    attr_accessor :command

    ## @return [String] Custom wrapper image to use, or nil to use the default.
    attr_accessor :wrapper_image


    ##
    # Executes the command synchronously. Streams the logs back to standard out
    # and does not return until the command has completed or timed out.
    #
    def start
      resolve_parameters

      version_info = version_info @service, @version
      env_variables = version_info["envVariables"] || {}
      beta_settings = version_info["betaSettings"] || {}
      cloud_sql_instances = beta_settings["cloud_sql_instances"] || []
      image = version_info["deployment"]["container"]["image"]

      config = build_config command, image, env_variables, cloud_sql_instances
      file = ::Tempfile.new ["cloudbuild_", ".json"]
      begin
        ::JSON.dump config, file
        file.flush
        Util::Gcloud.execute [
            "builds", "submit",
            "--no-source",
            "--config=#{file.path}",
            "--timeout=#{@timeout}"]
      ensure
        file.close!
      end
    end


    private

    ##
    # @private
    # Resolves and canonicalizes all the parameters.
    #
    def resolve_parameters
      unless @command.is_a? Array
        @command = ::Shellwords.parse @command.to_s
      end

      config_service = config_path = nil
      if @config_path || !@service
        config_service = begin
          config_path = @config_path || Exec.default_config_path
          ::YAML.load_file(config_path)["service"] || Exec.default_service
        rescue ::Errno::ENOENT
          raise ConfigFileNotFound.new config_path
        rescue
          raise BadConfigFileFormat.new config_path
        end
      end
      if @service && config_service && @service != config_service
        raise ServiceNameConflict.new @service, config_service, config_path
      end

      @service ||= config_service
      @version ||= latest_version @service
      @timeout ||= Exec.default_timeout
      @wrapper_image ||= Exec.default_wrapper_image
    end

    ##
    # @private
    # Builds a cloudbuild config as a data structure.
    #
    # @param command [Array<String>] The command in array form.
    # @param image [String] The fully qualified image path.
    # @param env_variables[Hash<String,String>] Environment variables.
    # @param cloud_sql_instances[String,Array<String>] Names of cloud sql
    #     instances to connect to.
    #
    def build_config command, image, env_variables, cloud_sql_instances
      args = ["-i", image]
      env_variables.each do |k, v|
        args << "-e" << "#{k}=#{v.gsub('$', '$$')}"
      end
      unless cloud_sql_instances.empty?
        cloud_sql_instances = Array(cloud_sql_instances)
        cloud_sql_instances.each do |sql|
          args << "-s" << sql
        end
      end
      args << "--"
      args += command

      {
        "steps" => [
          "name" => @wrapper_image,
          "args" => args
        ]
      }
    end

    ##
    # @private
    # Returns the name of the most recently created version of the given
    # service.
    #
    # @param service [String] Name of the service.
    # @return [String] Name of the most recent version.
    #
    def latest_version service
      result = Util::Gcloud.execute [
          "app", "versions", "list",
          "--service=#{service}",
          "--format=get(version.id)",
          "--sort-by=~version.createTime",
          "--limit=1"],
          capture: true, assert: false
      result = result.split.first
      raise NoSuchVersion.new(service) unless result
      result
    end

    ##
    # @private
    # Returns full information on the given version of the given service.
    #
    # @param service [String] Name of the service. If omitted, the service
    #     "default" is used.
    # @param version [String] Name of the version. If omitted, the most
    #     recently deployed is used.
    # @return [Hash,nil] A collection of fields parsed from the JSON
    #     representation of the version, or nil if the requested version
    #     doesn't exist.
    #
    def version_info service, version
      service ||= "default"
      version ||= latest_version service
      result = Util::Gcloud.execute [
          "app", "versions", "describe", version,
          "--service=#{service}",
          "--format=json"],
          capture: true, assert: false
      result.strip!
      raise NoSuchVersion.new(service, version) if result.empty?
      ::JSON.parse result
    end

  end

end
