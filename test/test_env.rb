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


      def test_extract_trace_id_absent
        env = {}
        trace_id = Env.extract_trace_id(env)
        assert_nil(trace_id)
      end


      def test_extract_trace_id_empty
        env = {'HTTP_X_CLOUD_TRACE_CONTEXT' => ''}
        trace_id = Env.extract_trace_id(env)
        assert_nil(trace_id)
      end


      def test_extract_trace_id_simple
        env = {'HTTP_X_CLOUD_TRACE_CONTEXT' => 'abcdefg'}
        trace_id = Env.extract_trace_id(env)
        assert_equal('abcdefg', trace_id)
      end


      def test_extract_trace_id_with_suffix
        env = {'HTTP_X_CLOUD_TRACE_CONTEXT' => 'abcdefg/hijk/lmnop'}
        trace_id = Env.extract_trace_id(env)
        assert_equal('abcdefg', trace_id)
      end


    end

  end
end
