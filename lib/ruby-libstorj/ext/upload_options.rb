module LibStorj
  module Ext
    module Storj
      class UploadOptions < FFI::Struct
        layout :prepare_frame_limit, :int,
               :push_frame_limit, :int,
               :push_shard_limit, :int,
               :rs, :bool,
               :index, :pointer, # char*
               :bucket_id, :pointer, # char*
               :file_name, :pointer, # char*
               :fd, :pointer # FILE*

        def initialize(options)
          bucket_id, file_path, file_name, index = options.values_at *(%i[bucket_id file_path file_name index])
          if file_path.nil? || !::File.exists?(file_path)
            raise Errno::ENOENT.new(file_path || 'nil')
          end

          file_name = ::File.basename(file_path) if !file_name
          super()

          self[:prepare_frame_limit] = 1
          self[:push_frame_limit] = 64
          self[:push_shard_limit] = 64
          self[:rs] = true
          self[:index] = (index.is_a?(String) && index.length == 64) ?
                             index : FFI::MemoryPointer::NULL
          self[:bucket_id] = FFI::MemoryPointer.from_string bucket_id
          self[:file_name] = FFI::MemoryPointer.from_string file_name
          self[:fd] = ::LibStorj::Ext::LibC.fopen file_path, 'r'
        end
      end
    end
  end
end