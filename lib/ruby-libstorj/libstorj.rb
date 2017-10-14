require 'rubygems'
require 'ffi'
require 'date'

module LibStorj
  # NB: not currently used but useful for debugging
  require 'ruby-libstorj/struct'
  require 'ruby-libstorj/ext/types'
  require 'ruby-libstorj/ext/json_request'
  require 'ruby-libstorj/ext/get_bucket_request'
  require 'ruby-libstorj/ext/create_bucket_request'
  require 'ruby-libstorj/ext/list_files_request'
  require 'ruby-libstorj/ext/bucket'
  require 'ruby-libstorj/ext/ext'
  require 'ruby-libstorj/ext/upload_options'
  require 'ruby-libstorj/ext/file'

  require 'ruby-libstorj/env'
  require 'ruby-libstorj/mixins/storj'

  extend ::LibStorj::Ext::Storj::Mixins
end
