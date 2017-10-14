module LibStorj
  module Ext
    module Storj
      class File < FFI::Struct
        extend FFI::Library
        ffi_lib('storj')

        attr_reader :name, :id, :size

        # typedef void (*storj_progress_cb)(double progress
        #                                  uint64_t bytes,
        #                                  uint64_t total_bytes,
        #                                  void *handle);
        PROGRESS_CALLBACK = callback %i[double uint64 uint64 pointer], :void

        # typedef void (*storj_finished_download_cb)(int status, FILE *fd, void *handle);
        FINISHED_DOWNLOAD_CALLBACK = callback %i[int pointer pointer], :void

        # typedef void (*storj_finished_upload_cb)(int error_status, char *file_id, void *handle);
        FINISHED_UPLOAD_CALLBACK = callback %i[int string pointer], :void

        def initialize(*args)
          super(*args)

          @name, @id, @size = self.values_at %i[filename id size]
        end

        def self.all(*args)
          _all(*args)
        end

        def self.pointer_to_array(pointer, array_length)
          if pointer.nil? || pointer == FFI::MemoryPointer::NULL || array_length < 1
            return nil
          end

          ### #=> [#<LibStorj::Ext::Storj::Bucket ...>, ...]
          (0..(array_length - 1)).map do |i|
            File.new pointer[i * size]
          end
        end

        attach_function('_all', 'storj_bridge_list_files', [
            Env.by_ref,
            :string,
            ::LibStorj::Ext::Storj::JsonRequest::CALLBACK,
            :pointer # uv_after_work_cb*
        ], :int)

        private :_all

        attach_function('delete', 'storj_bridge_delete_file', [
            Env.by_ref,
            :string,
            :string,
            ::LibStorj::Ext::Storj::JsonRequest::CALLBACK,
            :pointer, # after_work_cb
        ], :int)

        attach_function('resolve', 'storj_bridge_resolve_file', [
            Env.by_ref,
            ::LibStorj::Ext::Storj::DownloadState.by_ref,
            :string,
            :string,
            :pointer, # FILE* destination
            :pointer, # handle
            PROGRESS_CALLBACK, # progress_cb
            FINISHED_DOWNLOAD_CALLBACK, # finished_cb
        ], :int)

        attach_function('store', 'storj_bridge_store_file', [
            Env.by_ref,
            ::LibStorj::Ext::Storj::UploadState.by_ref,
            ::LibStorj::Ext::Storj::UploadOptions.by_ref,
            :pointer, # handle
            PROGRESS_CALLBACK, # progress_cb
            FINISHED_DOWNLOAD_CALLBACK, # finished_cb
        ], :int)
      end
    end
  end
end