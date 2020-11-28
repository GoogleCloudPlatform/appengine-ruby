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

lib = File.expand_path "lib", __dir__
$LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib
require "appengine/version"

::Gem::Specification.new do |spec|
  spec.name = "appengine"
  spec.version = ::AppEngine::VERSION
  spec.authors = ["Daniel Azuma"]
  spec.email = ["dazuma@gmail.com"]

  spec.summary = "Google App Engine integration tools"
  spec.description =
    "The appengine gem is a set of classes, plugins, and tools for" \
    " integration with Google App Engine. It provides access to the App" \
    " Engine runtime environment, including logging to the Google Cloud" \
    " Console and interrogation of hosting properties. It also provides Rake" \
    " tasks for managing your App Engine application, for example to run" \
    " production maintenance commands such as database migrations. This gem" \
    " is NOT required to deploy your Ruby application to App Engine."
  spec.license = "Apache-2.0"
  spec.homepage = "https://github.com/GoogleCloudPlatform/appengine-ruby"

  spec.files = ::Dir.glob("lib/**/*.rb") +
               ::Dir.glob("data/**/*") +
               ::Dir.glob("*.md") +
               ["LICENSE", ".yardopts"]
  spec.required_ruby_version = ">= 2.4.0"
  spec.require_paths = ["lib"]

  spec.add_dependency "google-cloud-env", "~> 1.4"
  spec.add_dependency "stackdriver", "~> 0.16"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "google-style", "~> 1.24.0"
  spec.add_development_dependency "minitest", "~> 5.11"
  spec.add_development_dependency "minitest-focus", "~> 1.1"
  spec.add_development_dependency "minitest-rg", "~> 5.2"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rdoc", "~> 6.0"
  spec.add_development_dependency "redcarpet", "~> 3.4"
  spec.add_development_dependency "toys", "~> 0.11"
  spec.add_development_dependency "yard", "~> 0.9"
end
