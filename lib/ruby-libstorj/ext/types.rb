module LibStorj
  module Ext
    # NB: Ruby's ffi doesn't allow assigning to :string' pointer
    #     types.
    #
    #     You can use `FFI::MemoryPointer.from_string` to create a
    #     string pointer from a ruby string. Or use the
    #     `FFI::Pointer#write_string` method to update an existing
    #     string (or generic) pointer; see below
    #
    # NB: All pointer types use have
    #       `read_<type> (FFI::Pointer#read_<type>)`
    #                 and
    #       `write_<type> (FFI::Pointer#write_<type>)`
    #     methods to read and write respectively

    module Curl
      extend FFI::Library
      require 'ruby-libstorj/ext/curl_code'

      enum(:curl_code, CURL_CODES)
    end

    module Storj
      extend FFI::Library

      class BridgeOptions < FFI::Struct
        layout :proto, :pointer,
               :host, :pointer,
               :port, :int,
               :user, :pointer,
               :pass, :pointer
      end

      class Bucket < FFI::Struct
        layout :created, :string,
               :name, :string,
               :id, :string,
               :decrypted, :bool
      end

      class File < FFI::Struct
        layout :created, :string,
               :filename, :string,
               :mimetype, :string,
               :erasure, :string,
               :size, :uint64,
               :hmac, :string,
               :id, :string,
               :decrypted, :bool,
               :index, :string
      end

      class UploadState < FFI::Struct
        layout :env, :pointer,
               :shard_concurrency, :uint32,
               :index, :string,
               :file_name, :string,
               :file_id, :string,
               :encrypted_file_name, :string,
               :original_file, :pointer, # FILE
               :file_size, :uint64,
               :bucket_id, :string,
               :bucket_key, :string,
               :completed_shards, :uint32,
               :total_shards, :uint32,
               :total_data_shards, :uint32,
               :total_parity_shards, :uint32,
               :shard_size, :uint64,
               :total_bytes, :uint64,
               :uploaded_bytes, :uint64,
               :exclude, :string,
               :frame_id, :string,
               :hmac_id, :string,
               :encryption_key, :uint8,
               :encryption_ctr, :uint8,
               :rs, :bool,
               :awaiting_parity_shards, :bool,
               :parity_file_path, :string,
               :parity_file, :pointer, # FILE
               :encrypted_file_path, :string,
               :encrypted_file, :pointer, # FILE
               :creating_encrypted_file, :bool,
               :requesting_frame, :bool,
               :completed_upload, :bool,
               :creating_bucket_entry, :bool,
               :received_all_pointers, :bool,
               :final_callback_called, :bool,
               :canceled, :bool,
               :bucket_verified, :bool,
               :file_verified, :bool,
               :progress_finished, :bool,
               :push_shard_limit, :int,
               :push_frame_limit, :int,
               :prepare_frame_limit, :int,
               :frame_request_count, :int,
               :add_bucket_entry_count, :int,
               :bucket_verify_count, :int,
               :file_verify_count, :int,
               :create_encrypted_file_count, :int,
               :progress_cb, :pointer, # storj_progress_cb
               :finished_cb, :pointer, # storj_finished_upload_cb
               :error_status, :int,
               :log, :pointer, # storj_log_levels_t
               :handle, :pointer,
               :shard, :pointer, # shard_tracker_t
               :pending_work_count, :int,
               #NB: workaround; `libstorj` segfaults without this when calling `storj_bridge_store_file`
               :fake_member, :pointer
      end

      class DownloadState < FFI::Struct
        layout :total_bytes, :uint64,
               :requesting_info, :bool,
               :info_fail_count, :uint32,
               :env, :pointer,
               :file_id, :string,
               :bucket_id, :string,
               :destination, :pointer, # FILE
               :progress_cb, :pointer, # storj_progress_cb
               :finished_cb, :pointer, # storj_finished_download_cb
               :finished, :bool,
               :canceled, :bool,
               :shard_size, :uint64,
               :total_shards, :uint32,
               :download_max_concurrency, :int,
               :completed_shards, :uint32,
               :resolving_shards, :uint32,
               :pointers, :pointer, # storj_pointer_t
               :excluded_farmer_ids, :string,
               :total_pointers, :uint32,
               :total_parity_pointers, :uint32,
               :rs, :bool,
               :recovering_shards, :bool,
               :truncated, :bool,
               :pointers_completed, :bool,
               :pointer_fail_count, :uint32,
               :requesting_pointers, :bool,
               :error_status, :int,
               :writing, :bool,
               :decrypt_key, :uint8,
               :decrypt_ctr, :uint8,
               :hmac, :string,
               :pending_work_count, :uint32,
               :log, :pointer, # storj_log_levels_t
               :handle, :pointer,
               #NB: workaround; `libstorj` segfaults without this when calling `storj_bridge_resolve_file`
               :fake_member, :pointer
      end

      class EncryptOptions < FFI::Struct
        layout :mnemonic, :pointer
      end

      class HttpOptions < FFI::Struct
        layout :user_agent, :pointer,
               :proxy_url, :pointer,
               :cainfo_path, :pointer,
               :low_speed_limit, :long,
               :low_speed_time, :long,
               :timeout, :long
      end

      class LogOptions < FFI::Struct
        layout :logger, :pointer,
               :level, :int
      end

      class Env < FFI::Struct
        layout :bridge_options, BridgeOptions.by_ref,
               :encrypt_options, EncryptOptions.by_ref,
               :http_options, HttpOptions.by_ref,
               :log_options, LogOptions.by_ref,
               :tmp_path, :pointer,
               :loop, :pointer, # uv_loop_t*
               :log, :pointer # storj_log_levels_t*
      end
    end

    module UV
      extend FFI::Library

      enum :uv_work_req, [
          :UV_UNKNOWN_REQ, 0,
          :UV_REQ,
          :UV_CONNECT,
          :UV_WRITE,
          :UV_SHUTDOWN,
          :UV_UDP_SEND,
          :UV_FS,
          :UV_WORK,
          :UV_GETADDRINFO,
          :UV_GETNAMEINFO,
          :UV_REQ_TYPE_PRIVATE,
          :UV_REQ_TYPE_MAX
      ]

      class Work < FFI::Struct
        layout :data, :pointer, # void*
               # read-only
               :type, :uv_work_req,
               # private
               :active_queue, :pointer,
               :reserved, :pointer,
               :loop, :pointer,
               :work_cb, :pointer,
               :after_work_cb, :pointer

        # void* active_queue[2];
        # void* reserved[4];
        # ...
        #   UV_WORK_PRIVATE_FIELDS
        # };
      end
    end

  end
end