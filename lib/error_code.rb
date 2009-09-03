module URLChecker
  ERR_UNKNOWN = 0
  ERR_CONNECTION_LOST = 1
  ERR_MISFORMAT_RESPONSE = 2
  ERR_TIMEOUT = 3
  ERR_HTTP_STATUS_MISMATCH = 4
  ERR_HTTP_CONTENT_MISMATCH = 5
  ERR_DNS_FAIL = 6
  ERR_NO_CONNECTION = 7
  ERR_HTTP_REDIRECTION_MISMATCH = 8
  
  def self.message(err_code)
    case err_code
    when ERR_UNKNOWN
      'Unknown'
    when ERR_CONNECTION_LOST
      'Connection Lost'
    when ERR_MISFORMAT_RESPONSE
      'Mistformat Response'
    when ERR_TIMEOUT
      'Timeout'
    when ERR_HTTP_STATUS_MISMATCH
      'HTTP Status Mismatch'
    when ERR_HTTP_CONTENT_MISMATCH
      'HTTP Content Mismatch'
    when ERR_DNS_FAIL
      'DNS错误'
    when ERR_NO_CONNECTION
      'No Connection'
    when ERR_HTTP_REDIRECTION_MISMATCH
      'Rerediction Mismatch'
    end
  end
  
  def self.map_dns_error(err)
    case err
      when Dnsruby::ResolvError
        1
      #A timeout error raised while querying for a resource
      when Dnsruby::ResolvTimeout
        2
      #The requested domain does not exist
      when Dnsruby::NXDomain
        3
      #A format error in a received DNS message
      when Dnsruby::FormErr
        4
      #Indicates a failure in the remote resolver
      when Dnsruby::ServFail
        5
      #The requested operation is not implemented in the remote resolver
      when Dnsruby::NotImp
        6
      #The requested operation was refused by the remote resolver
      when Dnsruby::Refused
        7
      #Another kind of resolver error has occurred
      when Dnsruby::OtherResolvError
        8
      #Indicates an error in decoding an incoming DNS message
      when Dnsruby::DecodeError
        9
      #Indicates an error encoding a DNS message for transmission
      when Dnsruby::EncodeError
        10
      #Indicates an error verifying 
      when Dnsruby::VerifyError
        11
      else
        0
    end
  end
end