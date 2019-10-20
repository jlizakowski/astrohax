
# Find the orbit count, and extemities of an elliptical orbit (min, max) for each orbit
class CircularHighLowFinder
	attr :high, :low, :direction
  attr_reader :cycle_highs, :cycle_lows, :count

	def initialize
		@low= Float::MAX
		@high= Float::MIN
		@diretion=:none
		@count=0

		@cycle_highs=[]
		@cycle_lows=[]
	end

	def check_high_low(n, payload)
    if (n > @high and n < @low)       #don't set a direction yet, and don't save anything to the list yet
      @high = n
      @low = n
    else
      set_high(n, payload) if n> @high
      set_low(n, payload) if n < @low
    end
    @count += 1
	end

	def set_high(n, payload)
		set_direction(:high, payload)
		@high = n
	end

	def set_low(n, payload)
		set_direction(:low, payload)
		@low = n
	end

	#This can be represented in faster math, but readability is chosen for this application
	def set_direction(new_dir, payload)
		if (direction != new_dir)  #toggle! Likely approaching 90 degrees vs high and low. If we find a new low, we are past the peak
			if @direction == :low and new_dir == :high
				@cycle_lows << [@low, @count, payload]   #record n so early noisy samples can be removed if desired
				@low= (@low+@high)/2.0   #set low to the avg, so it triggers around 90 degrees
			end
			if @direction == :high and new_dir == :low
				@cycle_highs << [@high, @count, payload]
				@high= (@low+@high)/2.0
			end
		end
		@direction=new_dir
  end

  def self.quick_test    #TODO: move to rspec
    f = CircularHighLowFinder.new
    [1.2, 5, 9.9, 9.9, 10.0, 9.9, 11, 10, 8 , 7, 1, 0 , -1, -4 , -10, -9, -12, 8, 3, 1, 9, -9, 80, -70, 12 , -10, 0].each{ |n| f.check_high_low(n); puts n;; pp f}; nil
    f.cycle_highs == [[11, 10], [9, 21], [80, 23]]  || raise("Test Failed")
    f.cycle_lows == [[-12, 17], [-9, 22]]    || raise("Test Failed")
    puts "Test Passed"
  end
end