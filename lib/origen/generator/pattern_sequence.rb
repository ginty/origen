require 'io/console'

module Origen
  class Generator
    # Manages a single pattern sequence, i.e. an instance of PatternSequence is
    # created for every Pattern.sequence do ... end block
    class PatternSequence
      def initialize(name, block)
        @number_of_threads = 1
        @name = name
        # The contents of the main Pattern.sequence block will be executed as a thread and treated
        # like any other parallel block
        thread = PatternThread.new(:main, self, block, true)
        threads << thread
        active_threads << thread
      end

      # Execute the given pattern
      def run(pattern_name)
        pattern = Origen.generator.pattern_finder.find(pattern_name.to_s, {})
        pattern = pattern[:pattern] if pattern.is_a?(Hash)
        load pattern
      end
      alias_method :call, :run

      def in_parallel(id = nil, &block)
        @number_of_threads += 1
        id ||= "thread#{@number_of_threads}".to_sym
        # Just stage the request for now, it will be started at the end of the current execute loop
        @parallel_blocks_waiting_to_start ||= []
        @parallel_blocks_waiting_to_start << [id, block]
      end

      private

      def log_execution_profile
        if threads.size > 1
          thread_id_size = threads.map { |t| t.id.to_s.size }.max
          line_size = IO.console.winsize[1] - 35 - thread_id_size
          line_size -= 16 if tester.try(:sim?)
          cycles_per_tick = (@cycle_count_stop / (line_size * 1.0)).ceil
          if tester.try(:sim?)
            execution_time = tester.execution_time_in_ns / 1_000_000_000.0
          else
            execution_time = Origen.app.stats.execution_time_for(Origen.app.current_job.output_pattern)
          end
          Origen.log.info ''
          tick_time = execution_time / line_size

          Origen.log.info "Concurrent execution profile (#{pretty_time(tick_time)}/increment):"
          Origen.log.info

          number_of_ticks = @cycle_count_stop / cycles_per_tick

          ticks_per_step = 0
          step_size = 0.1.us

          while ticks_per_step < 10
            step_size = step_size * 10
            ticks_per_step = step_size / tick_time
          end

          ticks_per_step = ticks_per_step.ceil
          step_size = tick_time * ticks_per_step

          if tester.try(:sim?)
            padding = '.' + (' ' * (thread_id_size + 1))
          else
            padding = ' ' * (thread_id_size + 2)
          end
          scale_step = '|' + ('-' * (ticks_per_step - 1))
          number_of_steps = (number_of_ticks / ticks_per_step) + 1
          scale = scale_step * number_of_steps
          scale = scale[0, number_of_ticks]
          Origen.log.info padding + scale

          scale = ''
          number_of_steps.times do |i|
            scale += pretty_time(i * step_size, 1).ljust(ticks_per_step)
          end
          scale = scale[0, number_of_ticks]
          Origen.log.info padding + scale

          threads.each do |thread|
            line = thread.execution_profile(0, @cycle_count_stop, cycles_per_tick)
            Origen.log.info ''
            Origen.log.info "#{thread.id}: ".ljust(thread_id_size + 2) + line
          end
          Origen.log.info ''
        end
      end

      def pretty_time(time, number_decimal_places = 0)
        return '0' if time == 0
        if time < 1.us
          "%.#{number_decimal_places}fns" % (time * 1_000_000_000)
        elsif time < 1.ms
          "%.#{number_decimal_places}fus" % (time * 1_000_000)
        elsif time < 1.s
          "%.#{number_decimal_places}fms" % (time * 1_000)
        else
          "%.#{number_decimal_places}fs" % tick_time
        end
      end

      def thread_completed(thread)
        active_threads.delete(thread)
      end

      def threads
        @threads ||= []
      end

      def active_threads
        @active_threads ||= []
      end

      def threads_waiting_to_start?
        @parallel_blocks_waiting_to_start
      end

      def execute
        active_threads.first.start
        until active_threads.empty?
          # Advance all threads to their next cycle point in sequential order. Keeping tight control of
          # when threads are running in this way ensures that the output is deterministic no matter what
          # computer it is running on, and ensures that the application code does not have to worry about
          # race conditions.
          cycs = active_threads.map do |t|
            t.advance
            t.pending_cycles
          end.compact.min

          if cycs
            # Now generate the required number of cycles which is defined by the thread that has the least
            # amount of cycles ready to go.
            # Since tester.cycle is being called by the master process here it will generate as normal (as
            # opposed to when called from a thread in which case it causes the thread to wait).
            cycs.cycles

            # Now let each thread know how many cycles we just generated, so they can decide whether they
            # need to wait for more cycles or if they can start preparing the next one
            active_threads.each { |t| t.executed_cycles(cycs) }
          end

          if @parallel_blocks_waiting_to_start
            @parallel_blocks_waiting_to_start.each do |id, block|
              thread = PatternThread.new(id, self, block)
              threads << thread
              active_threads << thread
              thread.start
            end
            @parallel_blocks_waiting_to_start = nil
          end
        end
        @cycle_count_stop = threads.first.current_cycle_count
      end
    end
  end
end
