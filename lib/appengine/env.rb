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


  # == Environment information
  #
  # A collection of functions for extracting App Engine environment information
  # from the Rack environment

  module Env


    # Returns the Trace ID string from a Rack environment, or nil if no trace
    # ID was found.

    def self.extract_trace_id(env)
      trace_context = env['HTTP_X_CLOUD_TRACE_CONTEXT'].to_s
      return nil if trace_context.empty?
      return trace_context.sub(/\/.*/, '')
    end


  end

end
