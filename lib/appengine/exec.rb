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
  # a command against it. For example, if your app runs on Ruby on Rails, then
  # you might use App Engine execution to run a command such as
  # `bundle exec bin/rails db:migrate` in production infrastructure (to avoid
  # having to connect directly to your production database from a local
  # workstation).
  #
  # App Engine execution provides two strategies for generating that "one-off
  # copy":
  #
  #  *  A `deployment` strategy, which deploys a temporary version of your app
  #     to a single backend instance and runs the command there.
  #  *  A `cloud_build` strategy, which deploys your application image to
  #     Google Cloud Build and runs the command there.
  #
  # Both strategies are generally designed to emulate the App Engine runtime
  # environment on cloud VMs similar to those used by actual deployments of
  # your app. Both provide your application code and environment variables, and
  # both provide access to Cloud SQL connections used by your app. However,
  # they differ in what *version* of your app code they run against, and in
  # certain other constraints and performance characteristics. More detailed
  # information on using the two strategies is provided in the sections below.
  #
  # Apps deployed to the App Engine *flexible environment* will use the
  # `cloud_build` strategy by default. However, you can force an app to use the
  # `deployment` strategy instead. (You might do so if you need to connect to a
  # Cloud SQL database on a VPC using a private IP, because the `cloud_build`
  # strategy does not support private IPs.) To force use of `deployment`, set
  # the `strategy` parameter in the {AppEngine::Exec} constructor (or the
  # corresponding `GAE_EXEC_STRATEGY` parameter in the Rake task). Note that
  # the `deployment` strategy is usually significantly slower than
  # `cloud_build` for apps in the flexible environment.
  #
  # Apps deployed to the App Engine *standard environment* will *always* use
  # the `deployment` strategy. You cannot force use of the `cloud_build`
  # strategy.
  #
  # ## Prerequisites
  #
  # To use App Engine remote execution, you will need:
  #
  # * An app deployed to Google App Engine, of course!
  # * The [gcloud SDK](https://cloud.google.com/sdk/) installed and configured.
  # * The `appengine` gem.
  #
  # You may use the `AppEngine::Exec` class to run commands directly. However,
  # in most cases, it will be easier to run commands via the provided rake
  # tasks (see {AppEngine::Tasks}).
  #
  # ## Using the "deployment" strategy
  #
  # The `deployment` strategy deploys a temporary version of your app to a
  # single backend App Engine instance, runs the command there, and then
  # deletes the temporary version when it is finished.
  #
  # This is the default strategy (and indeed the only option) for apps running
  # on the App Engine standard environment. It can also be used for flexible
  # environment apps, but this is not commonly done because deployment of
  # flexible environment apps can take a long time.
  #
  # Because the `deployment` strategy deploys a temporary version of your app,
  # it runs against the *current application code* present where the command
  # was initiated (i.e. the code currently on your workstation if you run the
  # rake task from your workstation, or the current code on the branch if you
  # are running from a CI/CD system.) This may be different from the code
  # actually running in production, so it is important that you run from a
  # compatible code branch.
  #
  # ### Specifying the host application
  #
  # The `deployment` strategy works by deploying a temporary version of your
  # app, so that it has access to your app's project and settings in App
  # Engine. In most cases, it can determine this automatically, but depending
  # on how your app or environment is structured, you may need to give it some
  # help.
  #
  # By default, your Google Cloud project is taken from the current gcloud
  # project. If you need to override this, set the `:project` parameter in the
  # {AppEngine::Exec} constructor (or the corresponding `GAE_PROJECT`
  # parameter in the Rake task).
  #
  # By default, the service name is taken from the App Engine config file.
  # App Engine execution will assume this file is called `app.yaml` in the
  # current directory. To use a different config file, set the `config_path`
  # parameter in the {AppEngine::Exec} constructor (or the corresponding
  # `GAE_CONFIG` parameter in the Rake task). You may also set the service name
  # directly, using the `service` parameter (or `GAE_SERVICE` in Rake).
  #
  # ### Providing credentials
  #
  # Your command will effectively be a deployment of your App Engine app
  # itself, and will have access to the same credentials. For example, App
  # Engine provides a service account by default for your app, or your app may
  # be making use of its own service account key. In either case, make sure the
  # service account has sufficient access for the command you want to run
  # (such as database admin credentials).
  #
  # ### Other options
  #
  # You may also provide a timeout, which is the length of time that App
  # Engine execution will allow your command to run before it is considered to
  # have stalled and is terminated. The timeout should be a string of the form
  # `2h15m10s`. The default is `10m`.
  #
  # The timeout is set via the `timeout` parameter to the {AppEngine::Exec}
  # constructor, or by setting the `GAE_TIMEOUT` environment variable when
  # invoking using Rake.
  #
  # ### Resource usage and billing
  #
  # The `deployment` strategy deploys to a temporary instance of your app in
  # order to run the command. You may be billed for that usage. However, the
  # cost should be minimal, because it will then immediately delete that
  # instance in order to minimize usage.
  #
  # If you interrupt the execution (or it crashes), it is possible that the
  # temporary instance may not get deleted properly. If you suspect this may
  # have happened, go to the App Engine tab in the cloud console, under
  # "versions" of your service, and delete the temporary version manually. It
  # will have a name matching the pattern `appengine-exec-<timestamp>`.
  #
  # ## Using the "cloud_build" strategy
  #
  # The `cloud_build` strategy takes the application image that App Engine is
  # actually using to run your app, and uses it to spin up a copy of your app
  # in [Google Cloud Build](https://cloud.google.com/cloud-build) (along with
  # an emulation layer that emulates certain App Engine services such as Cloud
  # SQL connection sockets). The command then gets run in the Cloud Build
  # environment.
  #
  # This is the default strategy for apps running on the App Engine flexible
  # environment. (It is not available for standard environment apps.) Note that
  # the `cloud_build` strategy cannot be used if your command needs to connect
  # to a database over a [VPC](https://cloud.google.com/vpc/) private IP
  # address. This is because it runs on virtual machines provided by the Cloud
  # Build service, which are not part of your VPC. If your database can be
  # accessed only over a private IP, you should use the `deployment` strategy
  # instead.
  #
  # ### Specifying the host application
  #
  # The `cloud_build` strategy needs to know exactly which app, service, and
  # version of your app, to identify the application image to use.
  #
  # By default, your Google Cloud project is taken from the current gcloud
  # project. If you need to override this, set the `:project` parameter in the
  # {AppEngine::Exec} constructor (or the corresponding `GAE_PROJECT`
  # parameter in the Rake task).
  #
  # By default, the service name is taken from the App Engine config file.
  # App Engine execution will assume this file is called `app.yaml` in the
  # current directory. To use a different config file, set the `config_path`
  # parameter in the {AppEngine::Exec} constructor (or the corresponding
  # `GAE_CONFIG` parameter in the Rake task). You may also set the service name
  # directly, using the `service` parameter (or `GAE_SERVICE` in Rake).
  #
  # By default, the image of the most recently deployed version of your app is
  # used. (Note that this most recently deployed version may not be the same
  # version that is currently receiving traffic: for example, if you deployed
  # with `--no-promote`.) To use a different version, set the `version`
  # parameter in the {AppEngine::Exec} constructor (or the corresponding
  # `GAE_VERSION` parameter in the Rake task).
  #
  # ### Providing credentials
  #
  # By default, the `cloud_build` strategy uses your project's Cloud Build
  # service account for its credentials. Unless your command provides its own
  # service account key, you may need to grant the Cloud Build service account
  # any permissions needed to execute your command (such as access to your
  # database). For most tasks, it is sufficient to grant Project Editor
  # permissions to the service account. You can find the service account
  # configuration in the IAM tab in the Cloud Console under the name
  # `[your-project-number]@cloudbuild.gserviceaccount.com`.
  #
  # ### Other options
  #
  # You may also provide a timeout, which is the length of time that App
  # Engine execution will allow your command to run before it is considered to
  # have stalled and is terminated. The timeout should be a string of the form
  # `2h15m10s`. The default is `10m`.
  #
  # The timeout is set via the `timeout` parameter to the {AppEngine::Exec}
  # constructor, or by setting the `GAE_TIMEOUT` environment variable when
  # invoking using Rake.
  #
  # You can also set the wrapper image used to emulate the App Engine runtime
  # environment, by setting the `wrapper_image` parameter to the constructor,
  # or by setting the `GAE_EXEC_WRAPPER_IMAGE` environment variable. Generally,
  # you will not need to do this unless you are testing a new wrapper image.
  #
  # ### Resource usage and billing
  #
  # The `cloud_build` strategy uses virtual machine resources provided by
  # Google Cloud Build. Generally, a certain number of usage minutes per day is
  # covered under a free tier, but additional compute usage beyond that time is
  # billed to your Google Cloud account. For more details,
  # see https://cloud.google.com/cloud-build/pricing
  #
  # If your command makes API calls or utilizes other cloud resources, you may
  # also be billed for that usage. However, the `cloud_build` strategy (unlike
  # the `deployment` strategy) does not use actual App Engine instances, and
  # you will not be billed for additional App Engine instance usage.
  #
  class Exec
    @default_timeout = "10m"
    @default_service = "default"
    @default_config_path = "./app.yaml"
    @default_wrapper_image = "gcr.io/google-appengine/exec-wrapper:latest"

    ##
    # Base class for exec-related usage errors.
    #
    class UsageError < ::StandardError
    end

    ##
    # Unsupported strategy
    #
    class UnsupportedStrategy < UsageError
      def initialize strategy, app_env
        @strategy = strategy
        @app_env = app_env
        super "Strategy \"#{strategy}\" not supported for the #{app_env}" \
              " environment"
      end
      attr_reader :strategy
      attr_reader :app_env
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
      def initialize service, version = nil
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
      #     If omitted, defaults to the value returned by
      #     {AppEngine::Exec.default_config_path}.
      # @param version [String,nil] Version string. If omitted, defaults to the
      #     most recently created version of the given service (which may not
      #     be the one currently receiving traffic).
      # @param timeout [String,nil] Timeout string. If omitted, defaults to the
      #     value returned by {AppEngine::Exec.default_timeout}.
      # @param wrapper_image [String,nil] The fully qualified name of the
      #     wrapper image to use. (Applies only to the "cloud_build" strategy.)
      # @param strategy [String,nil] The execution strategy to use, or `nil` to
      #     choose a default based on the App Engine environment (flexible or
      #     standard). Allowed values are `nil`, `"deployment"` (which is the
      #     default for Standard), and `"cloud_build"` (which is the default
      #     for Flexible).
      #
      def new_rake_task name, args: [], env_args: [],
                        service: nil, config_path: nil, version: nil,
                        timeout: nil, project: nil, wrapper_image: nil,
                        strategy: nil
        escaped_args = args.map do |arg|
          arg.gsub(/[,\[\]]/) { |m| "\\#{m}" }
        end
        name_with_args =
          if escaped_args.empty?
            name
          else
            "#{name}[#{escaped_args.join ','}]"
          end
        new ["bundle", "exec", "rake", name_with_args] + env_args,
            service: service, config_path: config_path, version: version,
            timeout: timeout, project: project, wrapper_image: wrapper_image,
            strategy: strategy
      end
    end

    ##
    # Create an execution for the given command.
    #
    # @param command [Array<String>] The command in array form.
    # @param project [String,nil] ID of the project. If omitted, obtains
    #     the project from gcloud.
    # @param service [String,nil] Name of the service. If omitted, obtains
    #     the service name from the config file.
    # @param config_path [String,nil] App Engine config file to get the
    #     service name from if the service name is not provided directly.
    #     If omitted, defaults to the value returned by
    #     {AppEngine::Exec.default_config_path}.
    # @param version [String,nil] Version string. If omitted, defaults to the
    #     most recently created version of the given service (which may not be
    #     the one currently receiving traffic).
    # @param timeout [String,nil] Timeout string. If omitted, defaults to the
    #     value returned by {AppEngine::Exec.default_timeout}.
    # @param wrapper_image [String,nil] The fully qualified name of the wrapper
    #     image to use. (Applies only to the "cloud_build" strategy.)
    # @param strategy [String,nil] The execution strategy to use, or `nil` to
    #     choose a default based on the App Engine environment (flexible or
    #     standard). Allowed values are `nil`, `"deployment"` (which is the
    #     default for Standard), and `"cloud_build"` (which is the default for
    #     Flexible).
    #
    def initialize command,
                   project: nil, service: nil, config_path: nil, version: nil,
                   timeout: nil, wrapper_image: nil, strategy: nil
      @command = command
      @service = service
      @config_path = config_path
      @version = version
      @timeout = timeout
      @project = project
      @wrapper_image = wrapper_image
      @strategy = strategy

      yield self if block_given?
    end

    ##
    # @return [String] The project ID.
    # @return [nil] if the default gcloud project should be used.
    #
    attr_accessor :project

    ##
    # @return [String] The service name.
    # @return [nil] if the service should be obtained from the app config.
    #
    attr_accessor :service

    ##
    # @return [String] Path to the config file.
    # @return [nil] if the default of `./app.yaml` should be used.
    #
    attr_accessor :config_path

    ##
    # @return [String] Service version of the image to use.
    # @return [nil] if the most recent should be used.
    #
    attr_accessor :version

    ##
    # @return [String] The command timeout, in `1h23m45s` format.
    # @return [nil] if the default of `10m` should be used.
    #
    attr_accessor :timeout

    ##
    # The command to run.
    #
    # @return [String] if the command is a script to be run in a shell.
    # @return [Array<String>] if the command is a posix command to be run
    #     directly without a shell.
    #
    attr_accessor :command

    ##
    # @return [String] Custom wrapper image to use.
    # @return [nil] if the default should be used.
    #
    attr_accessor :wrapper_image

    ##
    # @return [String] The execution strategy to use. Allowed values are
    #     `"deployment"` and `"cloud_build"`.
    # @return [nil] to choose a default based on the App Engine environment
    #     (flexible or standard).
    #
    attr_accessor :strategy

    ##
    # Executes the command synchronously. Streams the logs back to standard out
    # and does not return until the command has completed or timed out.
    #
    def start
      resolve_parameters
      app_info = version_info @service, @version
      resolve_strategy app_info["env"]
      if @strategy == "cloud_build"
        start_build_strategy app_info
      else
        start_deployment_strategy app_info
      end
    end

    private

    ##
    # @private
    # Resolves and canonicalizes all the parameters.
    #
    def resolve_parameters
      @timestamp_suffix = ::Time.now.strftime "%Y%m%d%H%M%S"
      @command = ::Shellwords.parse @command.to_s unless @command.is_a? Array
      @project ||= default_project
      @service ||= service_from_config || Exec.default_service
      @version ||= latest_version @service
      @timeout ||= Exec.default_timeout
      @timeout_seconds = parse_timeout @timeout
      @wrapper_image ||= Exec.default_wrapper_image
      self
    end

    def resolve_strategy app_env
      @strategy = @strategy.to_s.downcase
      if @strategy.empty?
        @strategy = app_env == "flexible" ? "cloud_build" : "deployment"
      end
      if app_env == "standard" && @strategy == "cloud_build" ||
         @strategy != "cloud_build" && @strategy != "deployment"
        raise UnsupportedStrategy.new @strategy, app_env
      end
      @strategy
    end

    def service_from_config
      return nil if !@config_path && @service
      @config_path ||= Exec.default_config_path
      ::YAML.load_file(config_path)["service"]
    rescue ::Errno::ENOENT
      raise ConfigFileNotFound, @config_path
    rescue ::StandardError
      raise BadConfigFileFormat, @config_path
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
      matched = timeout_str =~ /^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s?)?$/
      raise BadParameter.new "timeout", timeout_str unless matched
      hours = ::Regexp.last_match(1).to_i
      minutes = ::Regexp.last_match(2).to_i
      seconds = ::Regexp.last_match(3).to_i
      hours * 3600 + minutes * 60 + seconds
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
      raise NoSuchVersion, service unless result
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
    def start_deployment_strategy app_info
      describe_deployment_strategy
      entrypoint_file = app_yaml_file = temp_version = nil
      begin
        puts "\n---------- DEPLOY COMMAND ----------"
        secret = create_secret
        entrypoint_file = copy_entrypoint secret
        app_yaml_file = copy_app_yaml app_info, entrypoint_file
        temp_version = deploy_temp_app app_yaml_file
        puts "\n---------- EXECUTE COMMAND ----------"
        puts "COMMAND: #{@command.inspect}\n\n"
        exit_status = track_status temp_version, secret
        puts "\nEXIT STATUS: #{exit_status}"
      ensure
        puts "\n---------- CLEANUP ----------"
        ::File.unlink entrypoint_file if entrypoint_file
        ::File.unlink app_yaml_file if app_yaml_file
        delete_temp_version temp_version
      end
    end

    def describe_deployment_strategy
      puts "\nUsing the `deployment` strategy for appengine:exec"
      puts "(i.e. deploying a temporary version of your app)"
      puts "PROJECT: #{@project}"
      puts "SERVICE: #{@service}"
      puts "TIMEOUT: #{@timeout}"
    end

    def create_secret
      ::SecureRandom.alphanumeric 20
    end

    def copy_entrypoint secret
      entrypoint_template =
        ::File.join(::File.dirname(::File.dirname(__dir__)),
                    "data", "exec_standard_entrypoint.rb.erb")
      entrypoint_file = "appengine_exec_entrypoint_#{@timestamp_suffix}.rb"
      erb = ::ERB.new ::File.read entrypoint_template
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
      yaml_data = {
        "runtime"        => app_info["runtime"],
        "service"        => @service,
        "entrypoint"     => "ruby #{entrypoint_file}",
        "env_variables"  => app_info["envVariables"],
        "manual_scaling" => { "instances" => 1 }
      }
      if app_info["env"] == "flexible"
        complete_flex_app_yaml yaml_data, app_info
      else
        complete_standard_app_yaml yaml_data, app_info
      end
      app_yaml_file = "appengine_exec_config_#{@timestamp_suffix}.yaml"
      ::File.open app_yaml_file, "w" do |file|
        ::Psych.dump yaml_data, file
      end
      app_yaml_file
    end

    def complete_flex_app_yaml yaml_data, app_info
      yaml_data["env"] = "flex"
      orig_path = (app_info["betaSettings"] || {})["module_yaml_path"]
      return unless orig_path
      orig_yaml = ::YAML.load_file orig_path
      copy_keys = ["skip_files", "resources", "network", "runtime_config",
                   "beta_settings"]
      copy_keys.each do |key|
        yaml_data[key] = orig_yaml[key] if orig_yaml[key]
      end
    end

    def complete_standard_app_yaml yaml_data, app_info
      yaml_data["instance_class"] = app_info["instanceClass"].sub(/^F/, "B")
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

    def track_status temp_version, secret
      host = "#{temp_version}.#{@service}.#{@project}.appspot.com"
      ::Net::HTTP.start host do |http|
        outpos = errpos = 0
        delay = 0.0
        loop do
          sleep delay
          uri = URI("http://#{host}/#{secret}")
          uri.query = ::URI.encode_www_form outpos: outpos, errpos: errpos
          response = http.request_get uri
          data = ::JSON.parse response.body
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
            delay = 1.0 if delay > 1.0
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
    def start_build_strategy app_info
      env_variables = app_info["envVariables"] || {}
      beta_settings = app_info["betaSettings"] || {}
      cloud_sql_instances = beta_settings["cloud_sql_instances"] || []
      image = app_info["deployment"]["container"]["image"]

      describe_build_strategy

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

    def describe_build_strategy
      puts "\nUsing the `cloud_build` strategy for appengine:exec"
      puts "(i.e. running your app image in Cloud Build)"
      puts "PROJECT: #{@project}"
      puts "SERVICE: #{@service}"
      puts "VERSION: #{@version}"
      puts "TIMEOUT: #{@timeout}"
      puts ""
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
        v = v.gsub "$", "$$"
        args << "-e" << "#{k}=#{v}"
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
