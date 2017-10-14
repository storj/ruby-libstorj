module LibStorj
  module Ext
    module Storj
      module Mixins
        def util_timestamp
          ::LibStorj::Ext::Storj.util_timestamp
        end

        def util_datetime
          # '%Q' - Number of milliseconds since 1970-01-01 00:00:00 UTC.
          DateTime.strptime(::LibStorj::Ext::Storj.util_timestamp.to_s, '%Q')
        end

        def mnemonic_check(mnemonic)
          ::LibStorj::Ext::Storj.mnemonic_check(mnemonic)
        end

        # default to highest strength; strength range: (128..256)
        def mnemonic_generate(strength = 256)
          pointer = FFI::MemoryPointer.new :pointer, 1
          ::LibStorj::Ext::Storj.mnemonic_generate(strength, pointer)
          pointer.read_pointer.read_string
        end
      end
    end
  end
end
