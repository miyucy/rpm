require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))

module NewRelic::Agent
  class CrossProcessMonitorTest < Test::Unit::TestCase
    AGENT_CROSS_PROCESS_ID = "qwerty"
    REQUEST_CROSS_PROCESS_ID = "asdf"

    def setup
      NewRelic::Agent.instance.stubs(:cross_process_id).returns(AGENT_CROSS_PROCESS_ID)
      NewRelic::Agent.instance.stubs(:cross_process_encoding_bytes).returns([0])

      @request_with_id = {'X-NewRelic-ID' => REQUEST_CROSS_PROCESS_ID}
      @empty_request = {}

      @response = {}

      @monitor = NewRelic::Agent::CrossProcessMonitor.new()
    end

    def test_adds_response_header
      timings = stub(
        :transaction_name => "transaction",
        :queue_time_in_millis => 1000,
        :app_time_in_millis => 2000)

      NewRelic::Agent::BrowserMonitoring.stubs(:timings).returns(timings)

      @monitor.insert_response_header(@request_with_id, @response)

      assert unpacked_response.include?("transaction")
      assert unpacked_response.include?("1000")
      assert unpacked_response.include?("2000")
      assert unpacked_response.include?("-1") # Unset content-length
      assert unpacked_response.include?(AGENT_CROSS_PROCESS_ID)
    end

    def test_doesnt_add_header_if_no_id_in_request
      @monitor.insert_response_header(@empty_request, @response)
      assert_nil response_app_data
    end

    def test_doesnt_add_header_if_no_id_on_agent
      NewRelic::Agent.instance.stubs(:cross_process_id).returns(nil)

      @monitor.insert_response_header(@request_with_id, @response)
      assert_nil response_app_data
    end

    def test_doesnt_add_header_if_config_disabled
      with_config(:'cross_process.enabled' => false) do
        @monitor.insert_response_header(@request_with_id, @response)
        assert_nil response_app_data
      end
    end

    def test_includes_content_length
      NewRelic::Agent::BrowserMonitoring.stubs(:timings).returns(stub_everything)

      @monitor.insert_response_header(@request_with_id.merge("Content-Length" => 3000), @response)
      assert unpacked_response.include?("3000")
    end

    def test_content_length_isnt_case_sensitive
      NewRelic::Agent::BrowserMonitoring.stubs(:timings).returns(stub_everything)

      @monitor.insert_response_header(@request_with_id.merge("cOnTeNt-LeNgTh" => 3000), @response)
      assert unpacked_response.include?("3000")
    end

    def test_finds_id_from_headers
      %w{X-NewRelic-ID HTTP_X_NEWRELIC_ID X_NEWRELIC_ID}.each do |key|
        request = { key => REQUEST_CROSS_PROCESS_ID }

        assert_equal(
          REQUEST_CROSS_PROCESS_ID, \
          @monitor.id_from_request(request),
          "Failed to find header on key #{key}")
      end
    end

    def test_doesnt_find_id_in_headers
      request = {}
      assert_nil @monitor.id_from_request(request)
    end

    def response_app_data
      @response['X-NewRelic-App-Data']
    end

    def unpacked_response
      Base64.decode64(response_app_data)
    end
  end
end
