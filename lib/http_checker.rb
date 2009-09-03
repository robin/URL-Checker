require 'eventmachine'
require 'error_code'

class HttpChecker < EventMachine::Protocols::HttpClient
  
  attr_writer :time_out
  def time_out
    @time_out || 30
  end
  
  def time_used
    @end_time ||= Time.now
    @end_time - @start_time
  end
  
  def self.request( args = {} )
    args[:port] ||= 80
    EventMachine.connect( args[:host], args[:port], self ) {|c|
      if args[:ssl]
        c.start_tls
      end
      # According to the docs, we will get here AFTER post_init is called.
      c.instance_eval {@args = args}
    }
  end
  
  # HACK:
  # derived from original HttpClient from em 0.10 to support timeout
  def post_init
    super
    @is_time_out = false
    EventMachine::add_timer(time_out) {
      @is_time_out = true
    }
  end
  
  # HACK:
  # derived from original HttpClient from em 0.10 to support errorcode
  def parse_response_line
    if @headers.first =~ /\AHTTP\/1\.[01] ([\d]{3})/
      @status = $1.to_i
    else
      set_deferred_status :failed, {
        :status => 0,
        :error => URLChecker::ERR_MISFORMAT_RESPONSE
      }
      close_connection
    end
  end
  
  # HACK:
  # derived from original HttpClient from em 0.10 to support errorcode
  def unbind
    if !@connected
      set_deferred_status :failed, {:status => 0, :error => URLChecker::ERR_CONNECTION_LOST}
    elsif (@read_state == :content and @content_length == nil)
      dispatch_response
    elsif (@read_state == :content && @content.size>0 && @headers.size>0 && @status)
      dispatch_response
    elsif @is_time_out
      set_deferred_status :failed, {:status => 0, :error => URLChecker::ERR_TIMEOUT }
    end
  end
  
  # HACK:
  # derived from original HttpClient from em 0.10 to support benchmark
  def dispatch_response
    @end_time = Time.now
    super
  end
  
  # HACK:
  # derived from original HttpClient from em 0.10 to modify user agent
  def send_request args
    args[:verb] ||= args[:method] # Support :method as an alternative to :verb.
    args[:verb] ||= :get # IS THIS A GOOD IDEA, to default to GET if nothing was specified?

    verb = args[:verb].to_s.upcase
    unless ["GET", "POST", "PUT", "DELETE", "HEAD"].include?(verb)
      set_deferred_status :failed, {:status => 0} # TODO, not signalling the error type
      return # NOTE THE EARLY RETURN, we're not sending any data.
    end

    request = args[:request] || "/"
    unless request[0,1] == "/"
      request = "/" + request
    end

    qs = args[:query_string] || ""
    if qs.length > 0 and qs[0,1] != '?'
      qs = "?" + qs
    end

    # Allow an override for the host header if it's not the connect-string.
    host = args[:host_header] || args[:host] || "_"
    # For now, ALWAYS tuck in the port string, although we may want to omit it if it's the default.
    port = args[:port]

    # POST items.
    postcontenttype = args[:contenttype] || "application/octet-stream"
    postcontent = args[:content] || ""
    raise "oversized content in HTTP POST" if postcontent.length > MaxPostContentLength

    # ESSENTIAL for the request's line-endings to be CRLF, not LF. Some servers misbehave otherwise.
    # TODO: We ASSUME the caller wants to send a 1.1 request. May not be a good assumption.
    req = [
      "#{verb} #{request}#{qs} HTTP/1.1",
      "Host: #{host}:#{port}",
      "User-agent: Watchdog/0.1",
      "Accept: text/html,application/xhtml+xml,application/xml"
    ]

    if verb == "POST" || verb == "PUT"
      req << "Content-type: #{postcontenttype}"
      req << "Content-length: #{postcontent.length}"
    end

    # TODO, this cookie handler assumes it's getting a single, semicolon-delimited string.
    # Eventually we will want to deal intelligently with arrays and hashes.
    if args[:cookie]
      req << "Cookie: #{args[:cookie]}"
    end

    req << ""
    reqstring = req.map {|l| "#{l}\r\n"}.join
    send_data reqstring

    if verb == "POST" || verb == "PUT"
      send_data postcontent
    end
  end
  
  def self.parse_header(header)
    header.inject({}) {|h, sec|
      if sec =~ /(.+?):(.+)/
        k = $1.downcase
        v = $2.strip
        h[k] = v
      end
      h
    }
  end
  
end