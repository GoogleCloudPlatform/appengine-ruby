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
;

expand :clean, paths: ["pkg", "doc", ".yardoc", "tmp"]

expand :minitest, libs: ["lib", "test"]

expand :rubocop

expand :yardoc do |t|
  t.generate_output_flag = true
  t.fail_on_warning = true
  # t.fail_on_undocumented_objects = true
end

expand :gem_build

expand :gem_build, name: "release", push_gem: true

expand :gem_build, name: "install", install_gem: true
