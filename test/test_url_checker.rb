require "test/unit"
require "url_checker"

class TestUrlChecker < Test::Unit::TestCase
  def test_checker
    EventMachine::run {
      URLChecker.check("http://www.google.com",{:content_match => 'google'}) {|c|
        p c
        EM.stop_event_loop
      }
    }
  end
end
