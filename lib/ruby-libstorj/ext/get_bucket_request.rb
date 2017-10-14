module LibStorj
  module Ext
    module Storj
      class GetBucketRequest < FFI::Struct
        layout :http_options, HttpOptions.by_ref,
               :encrypt_options, EncryptOptions.by_ref,
               :options, BridgeOptions.by_ref,
               :method, :string,
               :path, :string,
               :auth, :bool,
               :body, :pointer, # struct json_object *body;
               :response, :pointer, # struct json_object *body;
               :buckets, :pointer,
               :total_buckets, :uint32,
               :error_code, :int,
               :status_code, :int,
               :handle, :pointer # void*

        def self.after_work_cb
          args = [::LibStorj::Ext::UV::Work.by_ref, :int]

          FFI::Function.new :void, args do |work_req_ptr|
            req = self.new work_req_ptr[:data]
            buckets,total_buckets = req.values_at %i[buckets total_buckets]
            error = ::LibStorj::Ext::Curl.curl_code_to_string req[:error_code]
            c_handle = FFI::Function.new :void, %i[string pointer int], req[:handle]

            c_handle.call error, buckets, total_buckets
          end
        end

        def self.ruby_handle
          FFI::Function.new :void, %i[string pointer int] do
          |error, buckets_pointer, bucket_count|
            buckets = ::LibStorj::Ext::Storj::Bucket
                          .pointer_to_array buckets_pointer,
                                            bucket_count

            yield error, buckets
          end
        end
      end
    end
  end
end