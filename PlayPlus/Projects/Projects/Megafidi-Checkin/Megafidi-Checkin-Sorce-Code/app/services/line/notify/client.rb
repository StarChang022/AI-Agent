require 'net/http'
require 'uri'
require 'json'
module Line::Notify
  class Client

    include ActiveModel::Model
    attr_accessor :token, :message, :status, :res_message

    def initialize(attributes={})
      super

    end

    def run
      client = ApiClient.new
      res = client.message(token, message)

      @status = res.dig('status')
      @res_message = res.dig('message')
    end

    def self.message(token: nil, message: nil)
      client = ApiClient.new
      res = client.message(token, message)

      @status = res.dig('status')
      @res_message = res.dig('message')
    end

  end

  class ApiClient
    class ArgumentError < StandardError; end

    attr_reader :http, :uri

    def initialize
      @uri = URI.parse("https://notify-api.line.me/api/notify")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      @http = http
    end

    def message(token, message)
      token ||= ENV['LineNotifyToken']
      raise ArgumentError if token.nil? || message.nil?
      req = Net::HTTP::Post.new uri
      req["Authorization"] = "Bearer #{token}"
      req.set_form_data(message: message)
      res = http.start { |http| http.request req }
      JSON.parse(res.body)
    end
  end

end