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

require "erb"
require "json"
require "net/http"
require "securerandom"
require "shellwords"
require "tempfile"
require "yaml"

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
  # App Engine execution spins up a one-off copy of an App Engine app, and runs
  # a command against that deployment. For example, if your app runs on Ruby on
  # Rails, then your app provides a `bin/rails` tool, and you may invoke it
  # using App Engine execution---for example to run a command such as
  # `bundle exec bin/rails db:migrate` in the image.
  #
  # How the one-off copy is deployed depends on the App Engine environment (and
  # is constrained by the envrionment's internal design.) Specifically:
  #
  #  *  If your app is running on the App Engine *flexible environment* (using
  #     the `ruby` runtime), the App Engine execution tool uses the application
  #     Docker image that was built for your last deployment, spins it up in
  #     the Cloud Build service, and runs the command there.
  #  *  If your app is running on the App Engine *standard environment* (for
  #     example, using the `ruby25` runtime), the App Engine execution tool
  #     deploys a temporary version of your app to a single backend instance,
  #     and runs the command there.
  #
  # A more detailed discussion of what this means is given below. However, both
  # cases are generally designed to emulate the App Engine environment on cloud
  # virtual machines, and are useful for production maintenance tasks such as
  # database migrations. For example:
  #
  #  *  Execution uses the same runtime environment (container) that runs your
  #     app in App Engine itself.
  #  *  Execution provides access to Cloud SQL connections used by your app.
  #  *  Execution sets environment variables configured by your application's
  #     `app.yaml` file.
  #
  # ## Prerequisites
  #
  # To use App Engine remote execution, you will need:
  #
  # * An app deployed to Google App Engine, of course!
  # * The gcloud SDK installed and configured. See https://cloud.google.com/sdk/
  # * The `appengine` gem.
  #
  # You may use the `AppEngine::Exec` class to run commands directly. However,
  # in most cases, it will be easier to run commands via the provided rake
  # tasks (see {AppEngine::Tasks}).
  #
  # ## Providing credentials
  #
  # If your app is running on the App Engine *flexible environment* (i.e. you
  # have `env: flex` in your `app.yaml` configuration file), you may also need
  # to grant the Cloud Build service account any permissions needed to execute
  # your command. For most tasks, it is sufficient to grant Project Editor
  # permissions to the service account. You can find the service account
  # configuration in the IAM tab in the Cloud Console under the name
  # `[your-project-number]@cloudbuild.gserviceaccount.com`.
  #
  # If your app is running on the App Engine *standard environment* (i.e. you
  # do *not* have `env: flex` in your `app.yaml` configuration file), then your
  # app uses the same credentials used by your app itself. In particular, it
  # uses the normal App Engine service account credentials (or, you may provide
  # your own service account key the same way you would for your app itself.)
  # Make sure the service account you use has sufficient permissions to perform
  # the task you want to perform.
  #
  # ## Specifying the hosting application
  #
  # When you run a command, you need to specify which application the command
  # is "connected to"--- that is, where the needed application code and configs
  # come from. For example, if you are running a database migration for a Rails
  # app, you must provide an application code base that includes the migration
  # classes and `database.yml` configuration.
  #
  # First, you can specify the project in which your app runs. By default, App
  # Engine execution will use the default project in your `gcloud` settings.
  # You can override this by setting the `project` parameter in the
  # {AppEngine::Exec} constructor.
  #
  # If your app runs on the App Engine *flexible environment*, the hosting
  # application is the application *image* used by an *existing deployment*.
  # Specifically, the most recent deployment is used (regardless of whether or
  # not that version is actually receiving traffic.) By default App Engine
  # execution will look in your current diretory for the App Engine config file
  # `app.yaml`, and determine from it which service you are deploying to, and
  # then determine the most recently deployed version. You can override this
  # behavior by setting the `config_path`, `service`, and/or `version`
  # parameters in the constructor of {AppEngine::Exec}. Setting `config_path`
  # lets you point to a different App Engine config file. Setting `service`
  # ignores the config file and specifies a service name directly. Setting
  # `version` lets you specify a version by name instead of using the most
  # recently deployed.
  #
  # If your app runs on the App Engine *standard environment*, the hosting
  # application is a *new deployment* of your app, from source on your local
  # workstation. Again, you may provide the `config_path` or `service`
  # parameters to the {AppEngine::Exec} constructor to specify an App Engine
  # service. (However, you cannot specify a `version` because, on the standard
  # environment, App Engine execution deploys a new version rather than using
  # an existing one.)
  #
  # When invoking App Engine execution using rake, you can set these parameters
  # using the `GAE_PROJECT`, `GAE_CONFIG`, `GAE_SERVICE`, and/or `GAE_VERSION`
  # environment variables.
  #
  # ## Other options
  #
  # You may also provide a timeout, which is the length of time that App
  # Engine execution will allow your command to run before it is considered to
  # have stalled and is terminated. The timeout should be a string of the form
  # `2h15m10s`. The default is `10m`.
  #
  # The timeout is set via the `timeout` parameter to the {AppEngine::Exec}
  # constructor, or by setting the `GAE_TIMEOUT` environment variable when
  # invoking using rake.
  #
  # Finally, on if your app runs on the App Engine *flexible environment*, you
  # can set the wrapper image used to emulate the App Engine runtime
  # environment, by setting the `wrapper_image` parameter to the constructor,
  # or by setting the `GAE_EXEC_WRAPPER_IMAGE` environment variable. Generally,
  # you will not need to do this unless you are testing a new wrapper image.
  # The wrapper image is not used with the App Engine standard environment.
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
    @default_wrapper_image =
      "gcr.io/google-appengine/exec-wrapper:latest".freeze

    ##
    # Base class for exec-related usage errors.
    #
    class UsageError < ::StandardError
    end

    ##
    # Exception raised when a parameter is malformed.
    #
    class BadParameter < UsageError
      def initialize param, value
        @param_name = param
        @value = value
        super "Bad value for #{param}: #{value}"
      end
      attr_reader :param_name
      attr_reader :value
    end

    ##
    # Exception raised when gcloud has no default project.
    #
    class NoDefaultProject < UsageError
      def initialize
        super "No default project set."
      end
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
                        timeout: nil, project: nil
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
            timeout: timeout, project: project
      end
    end

    ##
    # Create an execution for the given command.
    #
    # @param command [Array<String>] The command in array form.
    # @param project [String,nil] Name of the project. If omitted, obtains
    #     the project from gcloud.
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
                   project: nil, service: nil, config_path: nil, version: nil,
                   timeout: nil, wrapper_image: nil
      @command = command
      @service = service
      @config_path = config_path
      @version = version
      @timeout = timeout
      @project = project
      @wrapper_image = wrapper_image

      yield self if block_given?
    end

    ## @return [String,nil] The project ID, or nil to read from gcloud.
    attr_accessor :project

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

      app_info = version_info @service, @version
      case app_info["env"]
      when "flexible"
        start_flexible app_info
      when "standard"
        start_standard app_info
      else
        raise NoSuchVersion.new @service, @version
      end
    end

    private

    ##
    # @private
    # Resolves and canonicalizes all the parameters.
    #
    def resolve_parameters
      @timestamp_suffix = ::Time.now.strftime "%Y%m%d%H%M%S"
      unless @command.is_a? Array
        @command = ::Shellwords.parse @command.to_s
      end
      @project ||= default_project
      @service ||= service_from_config || Exec.default_service
      @version ||= latest_version @service
      @timeout ||= Exec.default_timeout
      @timeout_seconds = parse_timeout @timeout
      @wrapper_image ||= Exec.default_wrapper_image
    end

    def service_from_config
      return nil if !@config_path && @service
      @config_path ||= Exec.default_config_path
      ::YAML.load_file(config_path)["service"]
    rescue ::Errno::ENOENT
      raise ConfigFileNotFound.new @config_path
    rescue
      raise BadConfigFileFormat.new @config_path
    end

    def default_project
      result = Util::Gcloud.execute \
        ["config", "get-value", "project"],
        capture: true, assert: false
      result.strip!
      raise NoDefaultProject if result.empty?
      result
    end

    def parse_timeout timeout_str
      if timeout_str =~ /^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s?)?$/
        hours = ::Regexp.last_match(1).to_i
        minutes = ::Regexp.last_match(2).to_i
        seconds = ::Regexp.last_match(3).to_i
        hours * 3600 + minutes * 60 + seconds
      else
        raise BadParameter.new "timeout", timeout_str
      end
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
      result = Util::Gcloud.execute \
        [
          "app", "versions", "list",
          "--project", @project,
          "--service", service,
          "--format", "get(version.id)",
          "--sort-by", "~version.createTime",
          "--limit", "1"
        ],
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
    # @return [Hash] A collection of fields parsed from the JSON representation
    #     of the version
    # @return [nil] if the requested version doesn't exist.
    #
    def version_info service, version
      service ||= "default"
      version ||= latest_version service
      result = Util::Gcloud.execute \
        [
          "app", "versions", "describe", version,
          "--project", @project,
          "--service", service,
          "--format", "json"
        ],
        capture: true, assert: false
      result.strip!
      raise NoSuchVersion.new(service, version) if result.empty?
      ::JSON.parse result
    end

    ##
    # @private
    # Performs exec on a GAE standard app.
    #
    def start_standard app_info
      entrypoint_file = app_yaml_file = temp_version = nil
      begin
        puts "\n---------- DEPLOY COMMAND ----------"
        secret = create_secret
        entrypoint_file = copy_entrypoint secret
        app_yaml_file = copy_app_yaml app_info, entrypoint_file
        temp_version = deploy_temp_app app_yaml_file
        puts "\n---------- EXECUTE COMMAND ----------"
        puts "COMMAND: #{@command.inspect}\n\n"
        exit_status = track_status app_info, temp_version, secret
        puts "\nEXIT STATUS: #{exit_status}"
      ensure
        puts "\n---------- CLEANUP ----------"
        ::File.unlink entrypoint_file if entrypoint_file
        ::File.unlink app_yaml_file if app_yaml_file
        delete_temp_version temp_version
      end
    end

    def create_secret
      ::SecureRandom.alphanumeric(20)
    end

    def copy_entrypoint secret
      entrypoint_template =
        ::File.join(::File.dirname(::File.dirname(__dir__)),
                    "data", "exec_standard_entrypoint.rb.erb")
      entrypoint_file = "appengine_exec_entrypoint_#{@timestamp_suffix}.rb"
      erb = ::ERB.new(::File.read(entrypoint_template))
      data = {
        secret: secret.inspect, command: command.inspect
      }
      result = erb.result_with_hash data
      ::File.open entrypoint_file, "w" do |file|
        file.write result
      end
      entrypoint_file
    end

    def copy_app_yaml app_info, entrypoint_file
      app_yaml_file = "appengine_exec_config_#{@timestamp_suffix}.yaml"
      yaml_data = {
        "runtime" => app_info["runtime"],
        "service" => @service,
        "entrypoint" => "ruby #{entrypoint_file}",
        "env_variables" => app_info["envVariables"] || {},
        "instance_class" => app_info["instanceClass"].sub(/^F/, "B"),
        "manual_scaling" => { "instances" => 1 }
      }
      ::File.open app_yaml_file, "w" do |file|
        ::Psych.dump yaml_data, file
      end
      app_yaml_file
    end

    def deploy_temp_app app_yaml_file
      temp_version = "appengine-exec-#{@timestamp_suffix}"
      Util::Gcloud.execute [
        "app", "deploy", app_yaml_file,
        "--project", @project,
        "--version", temp_version,
        "--no-promote", "--quiet"
      ]
      temp_version
    end

    def track_status app_info, temp_version, secret
      host = "#{temp_version}.#{@service}.#{@project}.appspot.com"
      ::Net::HTTP.start(host) do |http|
        outpos = errpos = 0
        delay = 0.0
        loop do
          sleep delay
          uri = URI("http://#{host}/#{secret}")
          uri.query = URI.encode_www_form({outpos: outpos, errpos: errpos})
          response = http.request_get uri
          data = JSON.parse response.body
          data["outlines"].each { |line| puts "[STDOUT] #{line}" }
          data["errlines"].each { |line| puts "[STDERR] #{line}" }
          outpos = data["outpos"]
          errpos = data["errpos"]
          return data["status"] if data["status"]
          if data["time"] > @timeout_seconds
            http.request_post "/#{secret}/kill", ""
            return "timeout"
          end
          if data["outlines"].empty? && data["errlines"].empty?
            delay += 0.1
            delay = 0.5 if delay > 0.5
          else
            delay = 0.0
          end
        end
      end
    end

    def delete_temp_version temp_version
      Util::Gcloud.execute [
        "app", "versions", "delete", temp_version,
        "--project", @project,
        "--service", @service,
        "--quiet"
      ]
    end

    ##
    # @private
    # Performs exec on a GAE flexible app.
    #
    def start_flexible app_info
      env_variables = app_info["envVariables"] || {}
      beta_settings = app_info["betaSettings"] || {}
      cloud_sql_instances = beta_settings["cloud_sql_instances"] || []
      image = app_info["deployment"]["container"]["image"]

      config = build_config command, image, env_variables, cloud_sql_instances
      file = ::Tempfile.new ["cloudbuild_", ".json"]
      begin
        ::JSON.dump config, file
        file.flush
        Util::Gcloud.execute [
          "builds", "submit",
          "--project", @project,
          "--no-source",
          "--config", file.path,
          "--timeout", @timeout
        ]
      ensure
        file.close!
      end
    end

    ##
    # @private
    # Builds a cloudbuild config as a data structure.
    #
    # @param command [Array<String>] The command in array form.
    # @param image [String] The fully qualified image path.
    # @param env_variables [Hash<String,String>] Environment variables.
    # @param cloud_sql_instances [String,Array<String>] Names of cloud sql
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
  end
end
