require 'openssl'
require_relative '../helpers/storj_options'
include LibStorjTest

RSpec.describe LibStorj::Env do
  let(:bucket_class) {::LibStorj::Ext::Storj::Bucket}
  let(:file_class) {::LibStorj::Ext::Storj::File}
  let(:instance) do
    described_class.new(*default_options)
  end

  after :each do
    # (see https://github.com/Storj/ruby-libstorj/issues/2)
    # Process.RLIMIT_MEMLOCK #=> 8
    instance.destroy
  end

  describe '.uv_queue_and_run' do
    # expose otherwise private `LibStorj::Env#uv_queue_and_run`
    before :all do
      module LibStorj
        class Env
          def uv_queue_and_run_test_proxy(*args, &block)
            uv_queue_and_run(*args, &block)
          end
        end
      end
    end

    context 'without error' do
      it 'yields the block asynchronously' do
        expect do |block|
          instance.uv_queue_and_run_test_proxy(&block)
        end.to yield_control
      end

      it 'returns a promise' do
        expect(instance.uv_queue_and_run_test_proxy do
          #-- noop
        end).to respond_to(:then, :catch)
      end
    end

    context 'catching an async error' do
      let(:test_error) {Exception.new 'test exception'}

      it 'raises an `ArgumentError`' do
        expect do
          instance.uv_queue_and_run_test_proxy do
            raise(test_error)
          end
        end.to raise_error(test_error)
      end
    end
  end

  describe 'new' do
    it 'returns an instance of the described class' do
      expect(instance).to be_an_instance_of(described_class)
    end
  end

  describe '@storj_env' do
    it 'does not point to NULL' do
      expect(instance.storj_env.to_ptr).not_to equal(FFI::Pointer::NULL)
    end

    it 'is an instance of the struct wrapper corresponding to its C analogue' do
      expect(instance.storj_env).to be_an_instance_of(described_class::C_ANALOGUE)
    end
  end

  describe '#get_info' do
    context 'without error' do
      it 'yields with an nil error and hash response' do
        instance.get_info do |error, info|
          expect(error).to be(nil)
          expect(info).to be_an_instance_of(Hash)
        end
      end
    end

    context 'with error' do
      it 'yields with an error and nil response' do
        instance.storj_env[:bridge_options][:host].write_string 'a.nonexistant.example'

        expect do |block|
          instance.get_info(&block)
        end.to yield_with_args(/couldn't resolve host name/i, nil)
      end
    end
  end

  describe '#get_buckets' do
    context 'without error' do
      let(:bucket_names) {%w[bucket1 bucket2 bucket3]}

      before do
        bucket_names.each &instance.method(:create_bucket)
      end

      after do
        bucket_names.each &instance.method(:delete_bucket)
      end

      it 'yields a nil error and an array of buckets' do
        expect do |block| #{|block| instance.get_bucekts(&block)}.to yield_with_args
          instance.get_buckets do |error, buckets|
            expect(error).to be(nil)
            expect(buckets.length).to be(bucket_names.length)
            expect(buckets).to satisfy do |buckets|
              bucket_names = buckets.map(&:name)
              names_match = bucket_names.all? &bucket_names.method(:include?)
              are_all_buckets = buckets.all? do |bucket|
                bucket.is_a? bucket_class
              end

              names_match && are_all_buckets
            end
          end
        end
      end
    end

    context 'with error' do
      it 'yields with a non-nil error value and nil response' do
        # (see https://tools.ietf.org/html/rfc2606)
        instance.storj_env[:bridge_options][:host].write_string 'a.nonexistant.example'

        expect do |block|
          instance.get_buckets(&block)
        end.to yield_with_args(/couldn't resolve host name/i, nil)
      end
    end
  end

  describe '#create_bucket' do
    let(:test_bucket_name) {'test'}

    # TODO: refactor error contexts into shared example group 'api request'
    context 'without error' do
      let(:bucket_class) {::LibStorj::Ext::Storj::Bucket}

      def clean_buckets(&block)
        catch(:no_bucket) do
          return get_test_bucket_id do |id|
            instance.delete_bucket(id, &block)
          end
        end

        yield
      end

      after do
        clean_buckets
      end

      it 'yields with nil error and the new bucket' do
        clean_buckets do
          instance.create_bucket(test_bucket_name) do |error, bucket|
            expect(error).to be(nil)
            expect(bucket).to be_an_instance_of(bucket_class)
          end
          sleep 3
        end
      end
    end

    context 'with error' do
      describe 'external error' do
        it 'yields with a non-nil error value and nil response' do
          # (see https://tools.ietf.org/html/rfc2606)
          instance.storj_env[:bridge_options][:host].write_string 'a.nonexistant.example'

          expect do |block|
            instance.create_bucket(test_bucket_name, &block)
          end.to yield_with_args(/couldn't resolve host name/i, nil)
        end
      end

      describe 'bucket name in use' do
        before do
          instance.create_bucket(test_bucket_name)
        end

        it 'yields with a bucket name in use error' do
          # (see https://tools.ietf.org/html/rfc2606)
          expect do |block|
            instance.create_bucket(test_bucket_name, &block)
          end.to yield_with_args(/name already used by another bucket/i, nil)
        end
      end
    end
  end

  describe '#delete_bucket' do
    let(:test_bucket_name) {'test'}

    before :each do
      instance.create_bucket(test_bucket_name)
    end

    # TODO: refactor error contexts into shared example group 'api request'
    context 'without error' do
      let(:bucket_class) {::LibStorj::Ext::Storj::Bucket}

      it 'yields with nil error' do
        get_test_bucket_id do |id|
          instance.delete_bucket(id) do |error|
            expect(error).to be(nil)
          end
        end
      end
    end

    context 'with error' do
      describe 'external error' do
        it 'yields with a non-nil error value and nil response' do
          # (see https://tools.ietf.org/html/rfc2606)
          instance.storj_env[:bridge_options][:host].write_string 'a.nonexistant.example'

          expect do |block|
            instance.delete_bucket(test_bucket_name, &block)
          end.to yield_with_args(/couldn't resolve host name/i)
        end
      end

      xdescribe 'malformed id error' do
        let(:malformed_bucket_id) {'this is not what a bucket id looks like'}

        it 'yields with a malformed id error' do
          instance.delete_bucket(malformed_bucket_id) do |error|
            expect(error).to match(/bucket id is malformed/i)
          end
        end
      end
    end
  end

  describe '#store_file' do
    let(:test_bucket_name) {'test'}
    let(:test_file_name) {'test.data'}
    let(:test_file_path) {File.join %W(#{__dir__} .. helpers upload.data)}
    let(:options) {{
        file_name: test_file_name
    }}
    let(:progress_block) {Proc.new do
      # ensure this block is called
    end}

    before do
      done = nil
      instance.create_bucket test_bucket_name do
        done = true
      end

      wait_for(done).to be_truthy
    end

    context 'without error' do
      it 'uploads a file of the same size to the the specified bucket' do
        get_test_bucket_id do |test_bucket_id|
          instance.store_file test_bucket_id,
                              test_file_path,
                              options,
                              progress_block do |file_id|
            if file_id.nil?
              fail %q(Please ensure the test file doesn't already exist; TODO: automate this)
            end

            expect(file_id).to match(/\w+/i)
            # ensure this block is called
          end
        end
      end
    end
  end

  xdescribe '#resolve_file' do
    let(:test_bucket_name) {'test'}
    let(:test_file_name) {'test.data'}
    let(:test_file_path) {File.join %W(#{__dir__} .. helpers download.data)}
    let(:expected_hash) {File.read test_file_path}
    let(:test_file_hash) {
      data = File.read test_file_path
      OpenSSL::Digest::SHA256.hexdigest data
    }
    let(:progress_block) {Proc.new do
      # ensure this block gets called
    end}

    after :each do
      if File.exists? test_file_path
        File.unlink test_file_path
      end
    end

    context 'without error' do
      it 'downloads a file with the same sha256sum as the uploaded test data' do
        get_test_file_id do |test_bucket_id, test_file_id|
          instance.resolve_file test_bucket_id,
                                test_file_id,
                                test_file_path,
                                progress_block do |*args|
            # ensure this block is called
            expect(expected_hash).to equal(test_file_hash)
          end
        end
      end
    end
  end

  describe '#list_files' do
    #NB: `#list_files` test requires files be added to the `test` bucket;
    #TODO: automate this'
    let(:test_bucket_name) {'test'}

    context 'without error' do
      it 'yields with a nil error and an array of files' do
        get_test_bucket_id do |test_bucket_id|
          instance.list_files(test_bucket_id) do |error, files|
            expect(error).to be(nil)
            expect(files).to be_an_instance_of(Array)
            expect(files).to satisfy do |files|
              files.all? {|file| file.is_a? file_class}
            end
          end
        end
      end
    end

    context 'with error' do
      describe 'external error' do
        it 'yields with a non-nil error value and nil response' do
          # (see https://tools.ietf.org/html/rfc2606)
          instance.storj_env[:bridge_options][:host].write_string 'a.nonexistant.example'

          expect do |block|
            instance.list_files(test_bucket_name, &block)
          end.to yield_with_args(/couldn't resolve host name/i, nil)
        end
      end

      xdescribe 'malformed id error' do
        let(:malformed_bucket_id) {'this is not what a bucket id looks like'}

        it 'yields with a malformed id error' do
          instance.list_files(malformed_bucket_id) do |error|
            expect(error).to match(/bucket id is malformed/i)
          end
        end
      end
    end
  end

  describe '#delete_file' do
    let(:test_bucket_name) {'test'}
    let(:test_file_name) {'test.data'}
    let(:test_file_path) {File.join %W(#{__dir__} .. helpers upload.data)}

    context 'without error' do
      it 'yields with nil error and the new bucket' do
        get_test_file_id do |test_file_id, test_bucket_id|
          instance.delete_file test_bucket_id, test_file_id do |error|
            expect(error).to be_nil
            instance.list_files test_bucket_id do |error, files|
              file_was_deleted = files.nil? || files.any {|file| file.name == test_file_name}
              expect(file_was_deleted).to be_truthy
            end
          end
        end
      end
    end

    context 'with error' do
      describe 'external error' do
        it 'yields with a non-nil error value and nil response' do
          # (see https://tools.ietf.org/html/rfc2606)
          instance.storj_env[:bridge_options][:host].write_string 'a.nonexistant.example'

          expect do |block|
            instance.create_bucket(test_bucket_name, &block)
          end.to yield_with_args(/couldn't resolve host name/i, nil)
        end
      end
    end
  end
end
