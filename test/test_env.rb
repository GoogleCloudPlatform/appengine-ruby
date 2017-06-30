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

require 'minitest/autorun'
require 'appengine'


module AppEngine
  module Tests  # :nodoc:

    class TestEnv < ::Minitest::Test  # :nodoc:

      def test_app_engine
        ::ENV["GAE_INSTANCE"] = "instance-123"
        assert Env.app_engine?
        ::ENV.delete "GAE_INSTANCE"
        refute Env.app_engine?
      end

    end

  end
end
