Pattern.create do

  ss "Test that basic cycling works"
  $tester.cycle
  10.times do
    dut.nvm.pin(:invoke).drive(1)
    $tester.cycle
  end
  10.times do |i|
    dut.nvm.pin(:invoke).drive(i.even? ? 0 : 1)
    $tester.cycle
  end

  ss "Test that the port API works"
  dut.nvm.pins(:porta).drive(0x55)
  $tester.cycle
  dut.nvm.pins(:porta).expect(0xAA)
  $tester.cycle
  dut.nvm.pins(:porta).drive!(0x55)
  dut.nvm.pins(:porta).dont_care!
  dut.nvm.pins(:porta).drive_hi!
  dut.nvm.pins(:porta).drive_very_hi!
  dut.nvm.pins(:porta).drive_lo!
  dut.nvm.pins(:porta).assert_hi!
  dut.nvm.pins(:porta).assert_lo!
  dut.nvm.pins(:porta).drive_lo

  ss "Test that the store method works"
  cc "This vector should capture the FAIL pin data"
  $tester.cycle
  $tester.store dut.nvm.pin(:fail)
  $tester.cycle
  cc "This vector should capture the FAIL pin and the PORTA data"
  $tester.cycle
  $tester.cycle
  $tester.cycle
  $tester.store dut.nvm.pin(:fail), dut.nvm.pins(:porta), :offset => -2
  $tester.cycle
  $tester.store_next_cycle dut.nvm.pin(:fail)
  cc "This vector should capture the FAIL pin data"
  $tester.cycle

  ss "Test calling a subroutine"
  cc "This vector should call subroutine 'sub1'"
  $tester.cycle
  $tester.call_subroutine("sub1")
  cc "This vector should call subroutine 'sub2'"
  $tester.cycle
  $tester.cycle
  $tester.call_subroutine("sub2", :offset => -1)

#  ss "Test generating a handshake inside a subroutine"
#  cc "The next line should have a global label 'sub3', but no vector"
#  $tester.start_subroutine("sub3")
#  $tester.handshake
#  cc "This vector should have a return statement"
#  $tester.cycle
#  $tester.end_subroutine
#
#  ss "Test generating a handshake with a readcode"
#  $tester.handshake(:readcode => 10)
#
#  ss "Test frequency counter"
#  $tester.freq_count(dut.nvm.pin(:dtst), :readcode => 33)

  ss "Test a single pin match loop"
  $tester.wait(:match => true, :time_in_us => 5000, :pin => dut.nvm.pin(:done), :state => :high)

  ss "Test a two pin match loop"
  $tester.wait(:match => true, :time_in_us => 5000,
               :pin => dut.nvm.pin(:done), :state => :high,
               :pin2 => dut.nvm.pin(:fail), :state2 => :low)
  dut.nvm.pin(:fail).assert(0)

  ss "Test looping, these vectors should be executed once"
  $tester.loop_vector("test_loop_1", 1) do
    dut.nvm.pins(:porta).drive(0xAA)
    $tester.cycle
    dut.nvm.pins(:porta).drive(0x55)
    $tester.cycle
  end

  ss "Test looping, these vectors should be executed 3 times"
  $tester.loop_vector("test_loop_2", 3) do
    dut.nvm.pins(:porta).drive(0xAA)
    $tester.cycle
    dut.nvm.pins(:porta).drive(0x55)
    $tester.cycle
  end

  ss "Test looping, these vectors should be executed 5 times"
  $tester.loop_vectors 5 do
    dut.nvm.pins(:porta).drive(0xAA)
    $tester.cycle
    dut.nvm.pins(:porta).drive(0x55)
    $tester.cycle
  end

#  ss "Test repeat_previous"
#  $tester.cycle
#  cc "Invoke should repeat previous for 10 cycles"
#  dut.nvm.pin(:invoke).repeat_previous = true
#  10.cycles
#  dut.nvm.pin(:invoke).repeat_previous = false
#  cc "All pins should repeat previous for 10 cycles, except the clk pin"
#  $tester.repeat_previous do
#    dut.nvm.pin(:clk).drive(1)
#    10.cycles
#  end
#  cc "All should return to the original state"
#  $tester.cycle

  ss "Test suspend compares"
  dut.nvm.pin(:fail).assert!(1)
  cc "The fail pin should not be compared on these vectors"
  $tester.ignore_fails(dut.nvm.pin(:fail)) do
    10.cycles
  end
  cc "And now it should"
  $tester.cycle

  ss "Test inhibit vectors and comments"
  cc "The invoke pin should be driving high on this cycle"
  dut.nvm.pin(:invoke).drive!(1)
  cc "This should be the last thing you see until 'Inhibit complete!'"
  $tester.inhibit_vectors_and_comments do
    cc "This should not be in the output file, or the following vectors"
    $tester.cycle
    dut.nvm.pin(:invoke).drive!(0)
    10.cycles
  end
  cc "Inhibit complete!"
  cc "The invoke pin should be driving low on this cycle"
  $tester.cycle

  ss 'Test applying explicit pin state values'
  dut.pin(:clk).drive('P')
  10.cycles
  dut.pin(:clk).expect('t')
  10.cycles
  dut.pin(:clk).drive(1)
  10.cycles
end
