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


lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'appengine/version'


::Gem::Specification.new do |spec|
  spec.name = "appengine"
  spec.version = ::AppEngine::VERSION
  spec.authors = ["Daniel Azuma"]
  spec.email = ["dazuma@gmail.com"]

  spec.summary = "Google App Engine integration tools"
  spec.description = "The appengine gem is a set of classes, plugins, and " +
      "tools for integration with Google App Engine. It provides access to " +
      "the App Engine runtime environment, including logging to the Google " +
      "Cloud Console and interrogation of hosting properties. It also " +
      "provides rake tasks for managing your App Engine application, for " +
      "example to run production maintenance commands. " +
      "This gem is not required to deploy your Ruby application to App Engine."
  spec.license = "Apache 2.0"
  spec.homepage = "https://github.com/GoogleCloudPlatform/appengine-ruby"

  spec.files = ::Dir.glob("lib/**/*.rb") +
    ::Dir.glob("*.md") + ["LICENSE", "Rakefile", ".yardopts"]
  spec.required_ruby_version = ">= 2.0.0"
  spec.require_paths = ["lib"]

  spec.add_dependency "google-cloud-env", "~> 1.0"
  spec.add_dependency "stackdriver", "~> 0.15"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rdoc", "~> 6.0"
  spec.add_development_dependency "yard", "~> 0.9"
end
