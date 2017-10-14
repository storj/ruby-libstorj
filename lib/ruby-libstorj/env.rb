module LibStorj
  class Env
    require 'libuv'
    require 'json'
    attr_reader :storj_env

    C_ANALOGUE = ::LibStorj::Ext::Storj::Env

    def initialize(*options)
      @storj_env = ::LibStorj::Ext::Storj.method(:init_env).call(*options)
      @storj_env[:loop] = ::Libuv::Ext.default_loop
    end

    def destroy
      ::LibStorj::Ext::Storj.destroy_env @storj_env
    end

    def get_info(&block)
      ruby_handle = ::LibStorj::Ext::Storj::JsonRequest.ruby_handle(&block)
      after_work_cb = ::LibStorj::Ext::Storj::JsonRequest.after_work_cb do |error|
        yield error if block_given?
      end

      uv_queue_and_run do
        ::LibStorj::Ext::Storj.get_info @storj_env,
                                        ruby_handle,
                                        after_work_cb
      end
    end

    def delete_bucket(bucket_id, &block)
      req_data_type = ::LibStorj::Ext::Storj::JsonRequest
      after_work_cb = req_data_type.after_work_cb
      ruby_handle = req_data_type.ruby_handle do |error|
        yield error if block_given?
      end

      uv_queue_and_run do
        ::LibStorj::Ext::Storj::Bucket.delete @storj_env,
                                              bucket_id,
                                              ruby_handle,
                                              after_work_cb
      end
    end

    def get_buckets(&block)
      req_data_type = ::LibStorj::Ext::Storj::GetBucketRequest
      after_work_cb = req_data_type.after_work_cb
      ruby_handle = req_data_type.ruby_handle(&block)

      uv_queue_and_run do
        ::LibStorj::Ext::Storj::Bucket.all @storj_env,
                                           ruby_handle,
                                           after_work_cb
      end
    end

    def create_bucket(name, &block)
      req_data_type = ::LibStorj::Ext::Storj::CreateBucketRequest
      after_work_cb = req_data_type.after_work_cb
      ruby_handle = req_data_type.ruby_handle(&block)

      uv_queue_and_run do
        ::LibStorj::Ext::Storj::Bucket.create @storj_env,
                                              name,
                                              ruby_handle,
                                              after_work_cb
      end
    end

    def list_files(bucket_id, &block)
      req_data_type = ::LibStorj::Ext::Storj::ListFilesRequest
      after_work_cb = req_data_type.after_work_cb
      ruby_handle = req_data_type.ruby_handle(&block)

      uv_queue_and_run do
        ::LibStorj::Ext::Storj::File.all @storj_env,
                                         bucket_id,
                                         ruby_handle,
                                         after_work_cb
      end
    end

    def delete_file(bucket_id, file_id, &block)
      req_data_type = ::LibStorj::Ext::Storj::JsonRequest
      after_work_cb = req_data_type.after_work_cb
      ruby_handle = req_data_type.ruby_handle(&block)

      uv_queue_and_run do
        ::LibStorj::Ext::Storj::File.delete @storj_env,
                                            bucket_id,
                                            file_id,
                                            ruby_handle,
                                            after_work_cb
      end
    end

    def resolve_file(bucket_id, file_id, file_path, progress_proc = nil)
      download_state = ::LibStorj::Ext::Storj::DownloadState.new
      file_descriptor = ::LibStorj::Ext::LibC.fopen(file_path, 'w+')

      progress_cb = FFI::Function.new :void, %i[double uint64 uint64 pointer] do
      |progress, downloaded_bytes, total_bytes, handle|
        progress_proc.call progress, downloaded_bytes, total_bytes if progress_proc
      end

      finished_cb = FFI::Function.new :void, %i[int pointer pointer] do |status, file_id, handle|
        # do error handling based on status
        yield file_id if block_given?
      end

      # ruby_handle = FFI::MemoryPointer::NULL
      ruby_handle = FFI::Function.new :void, [] do
      end

      uv_queue_and_run do
        ::LibStorj::Ext::Storj::File.resolve @storj_env,
                                             download_state,
                                             bucket_id,
                                             file_id,
                                             file_descriptor,
                                             ruby_handle,
                                             progress_cb,
                                             finished_cb
      end
    end

    def store_file(bucket_id, file_path, progress_proc = nil, options = {})
      options = progress_proc if progress_proc.is_a? Hash
      default_options = {
          bucket_id: bucket_id,
          file_path: file_path,
      }
      options = options.merge(default_options) {|key, oldval| oldval}

      upload_state = ::LibStorj::Ext::Storj::UploadState.new
      upload_options =
          ::LibStorj::Ext::Storj::UploadOptions.new options

      progress_cb = FFI::Function.new :void, %i[double uint64 uint64 pointer] do
      |progress, bytes, total_bytes|
        progress_proc.call progress, bytes, total_bytes if progress_proc
      end

      finished_cb = FFI::Function.new :void, %i[int string pointer] do
      |status, file_id, handle|
        # do error handling based on status
        yield file_id if block_given?
      end

      uv_queue_and_run do
        # upload_state[:env] = @storj_env
        ::LibStorj::Ext::Storj::File.store @storj_env,
                                           upload_state,
                                           upload_options,
                                           FFI::MemoryPointer::NULL,
                                           progress_cb,
                                           finished_cb
      end
    end

    def uv_queue_and_run
      reactor do |reactor|
        @chain = reactor.work do
          yield
        end.catch do |error|
          raise error
        end
      end
      @chain
    end

    private :uv_queue_and_run
  end
end
