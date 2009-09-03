require 'rubygems'
require 'eventmachine'
require 'uri'
require 'error_code'
require 'http_checker'

module URLChecker
  VERSION = '1.0.0'

  # Check the url
  #
  # Available options:
  #  :follow_redirect - whether to follow the redirection. Default is true
  #  :user_object - if you set this, it will be sent back in the argument of
  # the argument of the callback
  #  :content_match - match the content
  #
  # === Usage example
  #
  #  EventMachine::run {
  #     URLChecker.check("http://www.baidu.com",{:content_match => '百度'}) {|c|
  #       checker = c
  #     }
  #  }  
  def self.check(url, options = {}, &block)
    checker = Checker.new(url, options)
    checker.check(block)
  end
  
  class Checker
    @@checker_count = 0
    
    def self.checker_count
      @@checker_count
    end
    
    def initialize(url, expects={})
      set_url(url)
      
      @expect_http_status = Regexp.new(expects[:status_match] || '200')
      @http_content_match = expects[:content_match]
      
      @result = {}
      @redirect_depth = 0
    end
    
    def check(doneblock)
      @doneblock = doneblock
      @@checker_count += 1
      check_http
    end
      
    protected
    def set_url(url)
      @url = url
      @uri = URI.parse(@url)
      @ssl = (@uri.scheme == 'https')
    end
    
    def check_http
      host = @uri.host
      begin
        @http = HttpChecker.request(
          :host => host,
          :port => @uri.port,
          :request => @uri.path,
          :host_header => @uri.host,
          :query_string => @uri.query,
          :ssl  => @ssl
        )
      rescue
        puts $!.backtrace
        # don't retry here. initialize the connection may cost a lot of time
        check_http_error({:status => 0, :error => ERR_NO_CONNECTION})
      end
      if @http
        @http.callback {|response|
          check_http_response response
        }
        @http.errback {|response|
          check_http_error response
        }
      end
    end
    
    def check_http_response(response)
      headers = HttpChecker.parse_header response[:headers]
      @result[:header] = headers
      @result[:body] = response
      status_match = response[:status].to_s =~ @expect_http_status
      if !status_match && (response[:status] >= 300 && response[:status] < 400)
        set_url(headers['location'])
        @redirect_depth
        check_http
        return
      end
      @result[:error] = ERR_HTTP_STATUS_MISMATCH unless status_match
      content_match = true
      if @http_content_match && status_match
        if response[:status] >= 300 && response[:status] < 400
          composed_localtion = "http://"+ @uri.host.to_s + headers['location']
          content_match = 
              (headers['location'].strip.downcase == (@http_content_match.strip.downcase)) ||
              (composed_localtion.strip.downcase == (@http_content_match.strip.downcase))              
              
          @result[:error] = ERR_HTTP_REDIRECTION_MISMATCH unless content_match
        else
          # handle different charset
          match_gbk = Iconv.iconv('GBK', 'UTF-8',@http_content_match)[0] rescue nil
          match_gb2312 = Iconv.iconv('GB2312', 'UTF-8',@http_content_match)[0] rescue nil
          content_match = response[:content].include?(@http_content_match) ||
                          (match_gbk && response[:content].include?(match_gbk)) ||
                          (match_gb2312 && response[:content].include?(match_gb2312))
          @result[:error] = ERR_HTTP_CONTENT_MISMATCH unless content_match
        end
      end
      
      @result[:status] = response[:status]
      @result[:success] = (status_match && content_match) ? true : false
      @result[:time_used] = @http.time_used
      done
    end
    
    def check_http_error(response)
      @result[:status] = response[:status]
      @result[:success] = false
      @result[:time_used] = @http ? @http.time_used : 0
      @result[:error] = response[:error] || ERR_UNKNOWN
      done
    end
    
    def done
      @@checker_count -= 1
      @doneblock.call(@result) if @doneblock
    end
    
  end
end
