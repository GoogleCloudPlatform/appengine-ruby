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


require "google/serverless/exec"

## The Appengine gem uses the Google Serverless gem for remote execution.
# This may be used for safe running of ops and maintenance tasks, such as
# database migrations in a production serverless environment.
# See {Google::Serverless::Exec} for more information on the usage documentation

module AppEngine
  Exec = Google::Serverless::Exec
end
