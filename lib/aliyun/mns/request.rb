require 'base64'
module Aliyun::mns

  class RequestException < Exception
    attr_reader :content
    delegate :[], to: :content

    def initialize ex
      @content = Hash.xml_object(ex.to_s, "Error")
    rescue
      @content = {"Message" => ex.message}
    end
  end

  class Request
    attr_reader :uri, :method, :date, :body, :content_md5, :content_type, :content_length, :mns_headers
    delegate :access_id, :key, :host, to: :configuration

    class << self
      [:get, :delete, :put, :post].each do |m|
        define_method m do |*args, &block|
          p 'aaa'
          options = {method: m, path: args[0], mns_headers: {}, params: {}}
          p 'bbb'
          options.merge!(args[1]) if args[1].is_a?(Hash)
          p 'ccc'
          request = Aliyun::mns::Request.new(options)
          block.call(request) if block
          p 'eee'
          request.execute
          p 'ddd'
        end
      end
    end

    def initialize method: "get", path: "/", mns_headers: {}, params: {}
      conf = {
        host: host,
        path: path
      }
      p conf
      conf.merge!(query: params.to_query) unless params.empty?
      p 'xxxxxxxxxxxxxxxxxx'
      @uri = URI::HTTP.build(conf)
      p @uri
      @method = method
      @mns_headers = mns_headers.merge("x-mns-version" => "2015-06-06")
    end

    def content type, values={}
      ns = "http://mns.aliyuncs.com/doc/v1/"
      builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
        xml.send(type.to_sym, xmlns: ns) do |b|
          values.each{|k,v| b.send k.to_sym, v}
        end
      end
      @body = builder.to_xml
      @content_md5 = Base64::encode64(Digest::MD5.hexdigest(body)).chop
      @content_length = body.size
      @content_type = "text/xml;charset=utf-8"
    end

    def execute
      #date = DateTime.now.httpdate
      date = DateTime.civil(2015, 12, 15, 8, 31, 30, 0).httpdate
      p date
      headers =  {
        "Authorization" => authorization(date),
        "Content-Length" => content_length || 0,
        "Content-Type" => content_type,
        "Content-MD5" => content_md5,
        "Date" => date,
        "Host" => uri.host
      }.merge(mns_headers).reject{|k,v| v.nil?}
      begin
        p method
        p uri.to_s
        p headers
        RestClient.send *[method, uri.to_s, body, headers].compact
      #rescue RestClient::Exception => ex
        #raise RequestException.new(ex)
      end
    end

    private
    def configuration
      Aliyun::mns.configuration
    end

    def authorization date

      canonical_resource = [uri.path, uri.query].compact.join("?")
      p canonical_resource
      canonical_mq_headers = mns_headers.sort.collect{|k,v| "#{k.downcase}:#{v}"}.join("\n")
      p canonical_mq_headers
      method = self.method.to_s.upcase
      signature = [method, content_md5 || "" , content_type || "" , date, canonical_mq_headers, canonical_resource].join("\n")
      p signature
      signature = 'GET


Tue, 15 Dec 2015 08:31:30 GMT
x-mns-version:2015-06-06
/queues/captcha-staging/messages?peekonly=true&numOfMessages=10'
      sha1 = Digest::HMAC.digest(signature, key, Digest::SHA1)
      "MNS #{access_id}:#{Base64.encode64(sha1).chop}"
    end

  end
end
