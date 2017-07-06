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


module AppEngine

  ##
  # # AppEngine Rails integration
  #
  # A Railtie providing Rails integration with the Google App Engine runtime
  # environment.
  #
  # Specifically:
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
  # TODO
  #
  class Railtie < ::Rails::Railtie

    config.appengine = ::ActiveSupport::OrderedOptions.new

    rake_tasks do
      require "appengine/tasks"
    end

  end

end
