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


require "shellwords"
require "English"

module AppEngine
  module Util
    ##
    # A collection of utility functions and classes for interacting with an
    # installation of the gcloud SDK.
    #
    module Gcloud
      ##
      # Base class for gcloud related errors.
      #
      class Error < ::StandardError
      end

      ##
      # Exception raised when the gcloud binary could not be found.
      #
      class BinaryNotFound < Gcloud::Error
        def initialize
          super "GCloud binary not found in path"
        end
      end

      ##
      # Exception raised when the project gcloud config is not set.
      #
      class ProjectNotSet < Gcloud::Error
        def initialize
          super "GCloud project configuration not set"
        end
      end

      ##
      # Exception raised when gcloud auth has not been completed.
      #
      class GcloudNotAuthenticated < Gcloud::Error
        def initialize
          super "GCloud not authenticated"
        end
      end

      ##
      # Exception raised when gcloud fails and returns an error.
      #
      class GcloudFailed < Gcloud::Error
        def initialize code
          super "GCloud failed with result code #{code}"
        end
      end

      class << self
        ##
        # @private
        # Returns the path to the gcloud binary, or nil if the binary could
        # not be found.
        #
        # @return [String,nil] Path to the gcloud binary.
        #
        def binary_path
          unless defined? @binary_path
            @binary_path =
              if ::Gem.win_platform?
                `where gcloud` == "" ? nil : "gcloud"
              else
                path = `which gcloud`.strip
                path.empty? ? nil : path
              end
          end
          @binary_path
        end

        ##
        # @private
        # Returns the path to the gcloud binary. Raises BinaryNotFound if the
        # binary could not be found.
        #
        # @return [String] Path to the gcloud binary.
        # @raise [BinaryNotFound] The gcloud binary is not present.
        #
        def binary_path!
          value = binary_path
          raise BinaryNotFound unless value
          value
        end

        ##
        # @private
        # Returns the ID of the current project, or nil if no project has
        # been set.
        #
        # @return [String,nil] ID of the current project.
        #
        def current_project
          unless defined? @current_project
            params = [
              "config", "list", "core/project", "--format=value(core.project)"
            ]
            @current_project = execute params, capture: true
            @current_project = nil if @current_project.empty?
          end
          @current_project
        end

        ##
        # @private
        # Returns the ID of the current project. Raises ProjectNotSet if no
        # project has been set in the gcloud configuration.
        #
        # @return [String] ID of the current project.
        # @raise [ProjectNotSet] The project config has not been set.
        #
        def current_project!
          value = current_project
          raise ProjectNotSet if value.empty?
          value
        end

        ##
        # @private
        # Verifies that all gcloud related dependencies are satisfied.
        # Specifically, verifies that the gcloud binary is installed and
        # authenticated, and a project has been set.
        #
        # @raise [BinaryNotFound] The gcloud binary is not present.
        # @raise [ProjectNotSet] The project config has not been set.
        # @raise [GcloudNotAuthenticated] Gcloud has not been authenticated.
        #
        def verify!
          binary_path!
          current_project!
          auths = execute ["auth", "list", "--format=value(account)"],
                          capture: true
          raise GcloudNotAuthenticated if auths.empty?
        end

        ##
        # @private
        # Execute a given gcloud command in a subshell.
        #
        # @param args [Array<String>] The gcloud args.
        # @param echo [boolean] Whether to echo the command to the terminal.
        #     Defaults to false.
        # @param capture [boolean] If true, return the output. If false, return
        #     a boolean indicating success or failure. Defaults to false.
        # @param assert [boolean] If true, raise GcloudFailed on failure.
        #     Defaults to true.
        # @return [String,Integer] Either the output or the success status,
        #     depending on the value of the `capture` parameter.
        #
        def execute args, echo: false, capture: false, assert: true
          cmd_array = [binary_path!] + args
          cmd =
            if ::Gem.win_platform?
              cmd_array.join " "
            else
              ::Shellwords.join cmd_array
            end
          puts cmd if echo
          result = capture ? `#{cmd}` : system(cmd)
          code = $CHILD_STATUS.exitstatus
          raise GcloudFailed, code if assert && code != 0
          result
        end

        ##
        # @private
        # Execute a given gcloud command in a subshell, and return the output
        # as a string.
        #
        # @param args [Array<String>] The gcloud args.
        # @return [String] The command output.
        #
        def capture args
          execute args, capture: true
        end
      end
    end
  end
end
