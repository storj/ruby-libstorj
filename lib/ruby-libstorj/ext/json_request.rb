module LibStorj
  module Ext
    module Storj
      class JsonRequest < FFI::Struct
        CALLBACK = callback [:string, :string], :void

        layout :http_options, HttpOptions.by_ref,
               :options, BridgeOptions.by_ref,
               :method, :string,
               :path, :string,
               :auth, :bool,
               :body, :pointer, # struct json_object *body;
               :response, :pointer, # struct json_object *response;
               :error_code, :int,
               :status_code, :int,
               :handle, :pointer # void*

        def self.after_work_cb
          args = [::LibStorj::Ext::UV::Work.by_ref, :int]

          FFI::Function.new :void, args do |work_req_ptr|
            req = self.new work_req_ptr[:data]
            response = ::LibStorj::Ext::JsonC.stringify req[:response]
            error = ::LibStorj::Ext::Curl.curl_code_to_string req[:error_code]
            c_handle = FFI::Function.new :void, %i[string pointer], req[:handle]

            c_handle.call(error, response)
          end
        end

        def self.ruby_handle(&block)
          FFI::Function.new :void, %i[string string] do |error, response|
            begin
              response = JSON.parse response
            rescue JSON::ParserError => err
              error = err
              response = nil
            end

            if error.respond_to?(:empty?) && error.empty?
              response_error = response.nil? ? nil : response['error']
              error = response_error.nil? ? nil : response_error
            end

            yield error, response if block_given?
          end
        end
      end
    end
  end
end