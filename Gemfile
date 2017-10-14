source 'https://rubygems.org' do
  gem 'rake'
  gem 'ffi' # Ruby FFI lib
  gem 'libuv' # libuv FFI bindings for ruby (https://github.com/cotag/libuv)
  ### libuv documentation -- http://docs.libuv.org/en/v1.x/

  group :test do
    gem 'rspec'
    gem 'rspec-wait'
    gem 'simplecov'
    gem 'launchy'
  end

  group :development do
    gem 'pry' # debugging tools / REPL
    gem 'pry-byebug' # moar debugging tools
    gem 'rake-compiler'
    gem 'guard'
    gem 'guard-rake'
    # gem 'rice' # defining and doing ruby things in C.
  end
end
gemspec