module LibStorjTest
  require 'yaml'
  require 'ruby-libstorj'

  def build_options(type_map)
    options_yml = YAML.load_file "#{__dir__}/options.yml"
    options_yml.to_a.map do |option_group|
      group_name, options = option_group

      option_type = type_map[group_name.to_sym]
      member_field_hash = Hash[option_type.members.zip option_type.layout.fields]
      option_instance = option_type.new

      options.each do |option|
        name, value = [option[0].to_sym, option[1]]

        if name == :logger
          option_instance[:logger] = ::LibStorj::Ext::Storj.const_get value

          next
        end

        option_field = member_field_hash[name]

        # TODO: check types and/or error handle
        if option_field.nil?
          option_instance = FFI::MemoryPointer::NULL
        elsif option_field.is_a?(FFI::StructLayout::Pointer)
          # Assuming pointers are strings
          #
          pointer = FFI::MemoryPointer.from_string(value.nil? ? '' : value)
          option_instance[name] = pointer
        else
          option_instance[name] = value
        end

      end

      option_instance
    end
  end

  def default_options
    build_options bridge: ::LibStorj::Ext::Storj::BridgeOptions,
                  encrypt: ::LibStorj::Ext::Storj::EncryptOptions,
                  http: ::LibStorj::Ext::Storj::HttpOptions,
                  log: ::LibStorj::Ext::Storj::LogOptions
  end

  def get_test_bucket_id(&block)
    instance.get_buckets do |error, buckets|
      throw(:no_bucket) if buckets.nil?

      test_bucket = buckets.find {|bucket| bucket.name == test_bucket_name}
      throw(:no_bucket) unless test_bucket
      block.call test_bucket.id
    end
  end

  def get_test_file_id(&block)
    get_test_bucket_id do |test_bucket_id|
      instance.list_files test_bucket_id do |error, files|
        throw(:no_file) if files.nil?

        test_file = files.find {|file| file.name == test_file_name}
        throw(:no_file) unless test_file
        block.call test_file.id, test_bucket_id
      end
    end
  end


  def clean_buckets(&block)
    catch(:no_bucket) do
      return get_test_bucket_id do |id|
        instance.delete_bucket(id, &block)
      end
    end

    yield if block_given?
  end

  def clean_files(&block)
    catch(:no_bucket) do
      return get_test_bucket_id do |test_bucket_id|
        catch(:no_file) do
          get_test_file_id do |test_file_id|
            instance.delete_file(test_bucket_id, test_file_id, &block)
          end
        end
      end
    end

    yield if block_given?
  end
end
