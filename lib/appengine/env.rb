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


require "google/cloud/env"

module AppEngine
  ##
  # A convenience object that provides information on the Google Cloud
  # hosting environment. For example, you can call
  #
  #     if AppEngine::Env.app_engine?
  #       # Do something
  #     end
  #
  # Technically, `Env` is not actually a module, but is simply set to the
  # `Google::Cloud.env` object.
  #
  # This is provided mostly for backward compatibility with previous usage, and
  # is mildly deprecated. Generally, you should call `Google::Cloud.env`
  # directly instead. See the documentation for the `google-cloud-env` gem.
  #
  Env = ::Google::Cloud.env
end
