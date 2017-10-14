# NB: ArgForwardingTask allows aliasing of rake tasks
#     while also forwarding arguments. We're using it here to allow
#     the tasks, "spec", and "test" work identically
module LibStorj
  require 'rake'

  class ArgForwardingTask
    include Rake::DSL

    attr_reader :target_task
    attr_reader :alias_tasks

    def initialize(target_name, alias_names: [nil], args_deps_hash:, &block)
      @alias_tasks = {}
      @target_task = nil


      if alias_names.nil? || alias_names.empty? || alias_names.reject {|t| !t}.empty?
        unless block
          throw ArgumentError.new 'either a block or at least one alias is required for `ArgFowardingTask.new`'
        end

        block_wrapper = Proc.new do |task, args|
          deps = args_deps_hash.values.flatten
          yield task, args, deps
        end

        # if no aliases, just register the target
        #
        #:call-seq:
        #      ... v-- We're using this signature --v
        #      Rake::Task.define_task task_name, arguments => dependencies
        #(see https://github.com/ruby/rake/blob/68ef9140c11d083d8bb7ee5da5b0543e3a7df73d/lib/rake/dsl_definition.rb#L28)
        @target_task = task(target_name, args_deps_hash, &block_wrapper)
      else
        if block_given?
          block_wrapper = Proc.new do |task, args|
            deps = args_deps_hash.values.flatten
            yield task, args, deps
          end

          @target_task = task(target_name, args_deps_hash, &block_wrapper)
        else
          @target_task = task(target_name, args_deps_hash)
        end
        alias_names.flatten.each do |task_name|
          @alias_tasks[task_name] = task(task_name, args_deps_hash) do |t, args|
            @target_task.invoke(*args.to_a)
          end
        end
      end
    end

    def method_missing(name, *args, &block)
      @target_task.method(name).call(*args, &block)
    end
  end
end
