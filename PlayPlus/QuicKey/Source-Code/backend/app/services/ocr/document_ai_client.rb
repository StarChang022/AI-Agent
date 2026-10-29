require "net/http"
require "base64"

module Ocr
  # Google Document AI（Enterprise Document OCR，只取全文）同步辨識 client。見 docs/OCR辨識規格.md §3。
  #
  # 用 googleauth 拿 service account 的 access token，再以 Net::HTTP 打 REST
  # `processors/:id:process`；一次送一份文件（圖片或 PDF），回傳 response 的 `document`。
  #
  # 錯誤分兩種：
  # - Unavailable：環境變數缺值、金鑰讀不到、連線 / 認證失敗、processor 不存在、Google 5xx
  #   → 整個請求回 503 ocr_unavailable。不 fallback 假資料（避免正式環境誤跑 stub）。
  # - InvalidDocument：Google 回 400（檔案壞掉、格式不支援、頁數超過上限）
  #   → 只算這一張辨識失敗，其他張照常處理。
  class DocumentAiClient
    class Unavailable < StandardError; end
    class InvalidDocument < StandardError; end

    ENV_KEYS = %w[
      GCP_PROJECT_ID
      GCP_LOCATION
      GCP_OCR_PROCESSOR_ID
      GOOGLE_APPLICATION_CREDENTIALS
    ].freeze

    SCOPE        = "https://www.googleapis.com/auth/cloud-platform".freeze
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 60

    NETWORK_ERRORS = [
      Timeout::Error, SocketError, SystemCallError, IOError,
      OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError
    ].freeze

    # credentials 物件內含 access token 與到期時間，跨 request 共用。
    @credentials_lock = Mutex.new

    class << self
      # 任一環境變數缺值 → Unavailable。
      def from_env
        missing = ENV_KEYS.select { |k| ENV[k].blank? }
        raise Unavailable, "missing env: #{missing.join(', ')}" if missing.any?

        new(
          project_id:       ENV["GCP_PROJECT_ID"],
          location:         ENV["GCP_LOCATION"],
          processor_id:     ENV["GCP_OCR_PROCESSOR_ID"],
          credentials_path: ENV["GOOGLE_APPLICATION_CREDENTIALS"]
        )
      end

      # 回傳可用的 access token；快取在 class 層級，過期前 60 秒才向 Google 換新。
      def access_token_for(path)
        @credentials_lock.synchronize do
          @credentials ||= {}
          credentials = (@credentials[path] ||= load_credentials(path))
          if credentials.access_token.nil? || credentials.expires_within?(60)
            credentials.fetch_access_token!
          end
          credentials.access_token
        end
      rescue Signet::AuthorizationError, Faraday::Error => e
        raise Unavailable, "auth failed: #{e.class}"
      end

      private

      def load_credentials(path)
        File.open(path) do |io|
          Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: io, scope: SCOPE)
        end
      rescue SystemCallError, JSON::ParserError, ArgumentError => e
        raise Unavailable, "credentials unreadable: #{e.class}"
      end
    end

    def initialize(project_id:, location:, processor_id:, credentials_path:)
      @credentials_path = credentials_path
      @uri = URI("https://#{location}-documentai.googleapis.com/v1/projects/#{project_id}" \
                 "/locations/#{location}/processors/#{processor_id}:process")
    end

    # bytes: 檔案原始內容；mime_type: 例如 "image/jpeg"、"application/pdf"
    # 回傳 Document AI 的 document（Hash，key 為 camelCase，例如 "entities"、"pages"）。
    def process(bytes, mime_type)
      body = {
        rawDocument: { content: Base64.strict_encode64(bytes), mimeType: mime_type },
        skipHumanReview: true
      }.to_json

      request = Net::HTTP::Post.new(@uri)
      request["Content-Type"]  = "application/json"
      request["Authorization"] = "Bearer #{self.class.access_token_for(@credentials_path)}"
      request.body = body

      response = Net::HTTP.start(@uri.host, @uri.port, use_ssl: true,
                                 open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end

      handle_response(response)
    rescue *NETWORK_ERRORS => e
      raise Unavailable, "network error: #{e.class}"
    end

    private

    def handle_response(response)
      case response
      when Net::HTTPSuccess
        JSON.parse(response.body).fetch("document", {})
      when Net::HTTPBadRequest
        raise InvalidDocument, google_error_message(response)
      else
        # 401/403 金鑰權限、404 processor 不存在、429 Google 端限流、5xx 都視為服務不可用
        raise Unavailable, "HTTP #{response.code}: #{google_error_message(response)}"
      end
    rescue JSON::ParserError
      raise Unavailable, "invalid JSON from Document AI"
    end

    def google_error_message(response)
      JSON.parse(response.body).dig("error", "message").to_s
    rescue JSON::ParserError
      response.body.to_s.truncate(200)
    end
  end
end
