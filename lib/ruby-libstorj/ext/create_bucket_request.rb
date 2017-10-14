module LibStorj
  module Ext
    module Storj
      class CreateBucketRequest < FFI::Struct
        layout :http_options, HttpOptions.by_ref,
               :encrypt_options, EncryptOptions.by_ref,
               :bridge_options, BridgeOptions.by_ref,
               :bucket_name, :string,
               :encrypted_bucket_name, :string,
               :response, :pointer, # struct json_object *response;
               :bucket, Bucket.by_ref,
               :error_code, :int,
               :status_code, :int,
               :handle, :pointer # void*

        def self.after_work_cb
          args = [::LibStorj::Ext::UV::Work.by_ref, :int]

          FFI::Function.new :void, args do |work_req_ptr|
            req = new work_req_ptr[:data]
            response = ::LibStorj::Ext::JsonC.stringify req[:response]
            error = ::LibStorj::Ext::Curl.curl_code_to_string req[:error_code]
            c_handle = FFI::Function.new :void, %i[string pointer], req[:handle]

            next c_handle.call(error, ::FFI::MemoryPointer::NULL) unless error.empty?

            status_code, bucket = req.values_at %i[status_code bucket]
            if ((status_code > 299) || bucket.id.nil?) && error.empty?
              response_error = JSON.parse(response)['error']
              error = response_error
              next c_handle.call(error, ::FFI::MemoryPointer::NULL)
            end

            bucket_pointer = req[:bucket]
            c_handle.call nil, bucket_pointer
          end
        end

        def self.ruby_handle(&block)
          FFI::Function.new :void, %i[string pointer] do |error, bucket_pointer|
            bucket = if bucket_pointer.null?
                       nil
                     else
                       ::LibStorj::Ext::Storj::Bucket.new(bucket_pointer)
                     end

            yield error, bucket if block_given?
          end
        end
      end
    end
  end
end
