require 'rspec'

require_relative '../regexp_helpers'

describe 'Regexps' do
  before do
    @testcases = <<~HEREDOC
     3
     3.4
     0.6
     .343
     4.3e10
     -5
     -0         
     -23x10^55   
     -2.32343242x10^-3
     HEREDOC

    @failcases = <<~HEREDOC
    -       
    food
    HEREDOC
  end
  
  it 'should handle basic test cases' do
    # if we don't explode, that's a start
    positives = @testcases.lines.map { |line| line.match?(/#{$rfloat}/) }
    expect( positives.reduce(true){|elem, prod| prod && elem}).to eq(true)
    
    expect(@failcases.lines.map { |line| line.scan(/#{$rfloat}/) }.flatten).to eq([])
  end
  

end