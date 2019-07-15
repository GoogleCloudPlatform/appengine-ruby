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


require "bundler/gem_tasks"
require "rake/testtask"
require "rdoc/task"

CLEAN << ["pkg", "doc"]

::Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = ::FileList["test/test_*.rb"]
end

::RDoc::Task.new do |rd|
  rd.rdoc_dir = "doc"
  rd.main = "README.md"
  rd.rdoc_files.include "README.md", "CONTRIBUTING.md", "CHANGELOG.md", "lib/**/*.rb"
  rd.options << "--line-numbers"
  rd.options << "--all"
end

require "yard"
require "yard/rake/yardoc_task"
YARD::Rake::YardocTask.new

load "lib/appengine/tasks.rb"

task default: [:test]
