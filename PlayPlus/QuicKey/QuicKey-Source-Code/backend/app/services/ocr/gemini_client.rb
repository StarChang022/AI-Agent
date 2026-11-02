require "net/http"
require "base64"

module Ocr
  # Vertex AI Gemini（gemini-3.1-flash-lite）辨識憑證 client。見 docs/OCR辨識規格.md §3、docs/技術選型.md §6。
  #
  # 用 googleauth 拿 service account 的 access token，再以 Net::HTTP 打 REST `generateContent`；
  # 一次送一份文件（圖片或 PDF，base64 放 inline_data），以 responseSchema 要求模型直接回欄位 JSON。
  # - recognize：整份文件是同一張憑證（/api/ocr/recognize）
  # - locate_receipts：一頁裡可能有多張憑證，只找出每張的位置、不辨識內容（/api/ocr/batch 上傳時）；
  #   確認後每張裁成單張，再用 recognize 辨識
  #
  # 錯誤分兩種：
  # - Unavailable：環境變數缺值、金鑰讀不到、連線 / 認證失敗、模型不存在、Google 429 / 5xx
  #   → 整個請求回 503 ocr_unavailable。不 fallback 假資料（避免正式環境誤跑 stub）。
  # - InvalidDocument：Google 回 400（檔案壞掉、格式不支援、超過大小上限）
  #   → 只算這一張辨識失敗，其他張照常處理。
  class GeminiClient
    class Unavailable < StandardError; end
    class InvalidDocument < StandardError; end

    # data: 模型回的欄位 Hash（回應被截斷、被安全機制擋下、不是合法 JSON 時為 nil）
    Result = Struct.new(:data, keyword_init: true)

    ENV_KEYS = %w[
      GCP_PROJECT_ID
      GCP_LOCATION
      GOOGLE_APPLICATION_CREDENTIALS
    ].freeze

    MODEL        = "gemini-3.1-flash-lite".freeze
    SCOPE        = "https://www.googleapis.com/auth/cloud-platform".freeze
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 60
    # 輸出上限：欄位 JSON 很短，留足空間給思考 token，避免 JSON 寫到一半被截斷
    MAX_OUTPUT_TOKENS = 4096
    # 找位置只回框的座標
    MAX_OUTPUT_TOKENS_LOCATE = 2048
    # 抽欄位不需要推理，用最低思考量省 token
    THINKING_LEVEL = "minimal".freeze

    NETWORK_ERRORS = [
      Timeout::Error, SocketError, SystemCallError, IOError,
      OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError
    ].freeze

    FIELD_RULES = <<~TEXT.freeze
      - document_type：有發票字軌號碼的是 invoice；「免用統一發票」或收據是 receipt；看不出來填 null。
      - incurred_at：開立日期，西元 YYYY-MM-DD（民國年請加 1911）；沒有或不只一個不同日期填 null。
        手寫日期請逐位對照「年」「月」「日」字樣讀取，年、月、日各自是 1 到 3 位數字。
      - invoice_prefix / invoice_digits：發票字軌 2 碼英文與 8 碼數字（例如 AB-12345678 → AB、12345678）。
        交易明細、銷貨明細表上印的「發票號碼」也要填。銷帳編號、訂單號、取餐號、交易序號不是發票號碼；免用統一發票收據沒有發票號碼，填 null。
      - seller_name / seller_tax_id：賣方（開立憑證的店家）名稱與 8 碼統一編號。
        免用統一發票收據、手寫收據的賣方看蓋在上面的店章（免用發票專用章、收據專用章）：名稱填章上的店名（例如「○○商行」「○○市場」），
        統一編號填章上的統一編號；章上的電話、地址不是名稱。「銀貨兩訖」「收據專用章」「免用發票專用章」是固定字樣，不是店名。
        章上看不出店名時填 null。
      - buyer_name / buyer_tax_id：買方（「買受人」欄）名稱與 8 碼統一編號；收據上「統一編號」欄（在買受人旁或日期下方）是買方的統編。
      - pre_tax_amt / tax_amt / amount：銷售額（未稅）、營業稅額、總計（含稅應付金額），單位新台幣、整數；
        憑證上沒印的填 null。實收現金、找零不是 amount。
      - items：明細行，每筆 name、quantity、unit_price、subtotal；沒有明細填空陣列。
        好幾個品名共用一個總價時（例如寫「共 500」），合併成一筆，name 用「、」連接，subtotal 填那個總價。
      - uncertain_fields：你不確定（字跡模糊、手寫、被遮住、靠推測）的欄位名稱清單；手寫的欄位一律列入；都有把握就填空陣列。
      規則：圖片上看不到的欄位一律填 null，不要猜、不要編造；統一編號只填 8 碼數字。
    TEXT

    PROMPT = <<~TEXT.freeze
      你是台灣憑證（電子發票證明聯、收銀機發票、免用統一發票收據、手寫收據、請款單據）的資料擷取工具。
      讀取附件，只回傳 JSON，欄位如下：
      #{FIELD_RULES.chomp}
    TEXT

    LOCATE_PROMPT = <<~TEXT.freeze
      你是台灣憑證（電子發票證明聯、收銀機發票、免用統一發票收據、手寫收據、請款單據）的位置偵測工具。
      附件是一頁掃描檔或照片，上面可能有 0 到多張不同的憑證。找出每一張憑證的範圍，依由上到下、由左到右的順序，
      每張一筆放進 receipts：box_2d 為 [ymin, xmin, ymax, xmax]，座標以整頁為範圍、0 到 1000 正規化的整數；
      框要包住整張憑證（含店章、QR Code）。同一張憑證的正面、明細只算一筆；沒有任何憑證時回空陣列。
      不用讀取內容，只回傳 JSON。
    TEXT

    FIELD_NAMES = %w[
      document_type incurred_at invoice_prefix invoice_digits
      seller_name seller_tax_id buyer_name buyer_tax_id
      pre_tax_amt tax_amt amount items
    ].freeze

    RESPONSE_SCHEMA = {
      type: "OBJECT",
      properties: {
        document_type:   { type: "STRING", enum: %w[invoice receipt], nullable: true },
        incurred_at:     { type: "STRING", nullable: true },
        invoice_prefix:  { type: "STRING", nullable: true },
        invoice_digits:  { type: "STRING", nullable: true },
        seller_name:     { type: "STRING", nullable: true },
        seller_tax_id:   { type: "STRING", nullable: true },
        buyer_name:      { type: "STRING", nullable: true },
        buyer_tax_id:    { type: "STRING", nullable: true },
        pre_tax_amt:     { type: "INTEGER", nullable: true },
        tax_amt:         { type: "INTEGER", nullable: true },
        amount:          { type: "INTEGER", nullable: true },
        items: {
          type: "ARRAY",
          items: {
            type: "OBJECT",
            properties: {
              name:       { type: "STRING" },
              quantity:   { type: "NUMBER" },
              unit_price: { type: "NUMBER" },
              subtotal:   { type: "NUMBER" }
            },
            required: %w[name quantity unit_price subtotal]
          }
        },
        uncertain_fields: { type: "ARRAY", items: { type: "STRING", enum: FIELD_NAMES } }
      },
      required: %w[items uncertain_fields]
    }.freeze

    LOCATE_SCHEMA = {
      type: "OBJECT",
      properties: {
        receipts: {
          type: "ARRAY",
          items: {
            type: "OBJECT",
            properties: { box_2d: { type: "ARRAY", items: { type: "INTEGER" } } },
            required: %w[box_2d]
          }
        }
      },
      required: %w[receipts]
    }.freeze

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

    def initialize(project_id:, location:, credentials_path:)
      @credentials_path = credentials_path
      # global 端點沒有區域前綴；gemini-3.1-flash-lite 只開放 global / us / eu（見 OCR辨識規格 §3）
      host = location == "global" ? "aiplatform.googleapis.com" : "#{location}-aiplatform.googleapis.com"
      @uri = URI("https://#{host}/v1/projects/#{project_id}/locations/#{location}" \
                 "/publishers/google/models/#{MODEL}:generateContent")
    end

    # bytes: 檔案原始內容；mime_type: 例如 "image/jpeg"、"application/pdf"
    def recognize(bytes, mime_type)
      generate(bytes, mime_type, prompt: PROMPT, schema: RESPONSE_SCHEMA, max_output_tokens: MAX_OUTPUT_TOKENS)
    end

    # 一頁多張只找位置：data 為 { "receipts" => [ { "box_2d" => [ymin, xmin, ymax, xmax] }, ... ] }
    # （格式不對時同 recognize 為 nil）
    def locate_receipts(bytes, mime_type)
      generate(bytes, mime_type, prompt: LOCATE_PROMPT, schema: LOCATE_SCHEMA,
               max_output_tokens: MAX_OUTPUT_TOKENS_LOCATE)
    end

    private

    def generate(bytes, mime_type, prompt:, schema:, max_output_tokens:)
      body = {
        contents: [ {
          role: "user",
          parts: [
            { inline_data: { mime_type: mime_type, data: Base64.strict_encode64(bytes) } },
            { text: prompt }
          ]
        } ],
        generationConfig: {
          temperature: 0,
          maxOutputTokens: max_output_tokens,
          responseMimeType: "application/json",
          responseSchema: schema,
          thinkingConfig: { thinkingLevel: THINKING_LEVEL }
        }
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

    def handle_response(response)
      case response
      when Net::HTTPSuccess
        parse_success(JSON.parse(response.body))
      when Net::HTTPBadRequest
        classify_bad_request(response)
      else
        # 401/403 金鑰權限、404 模型 / 區域不存在、429 Google 端限流、5xx 都視為服務不可用
        raise Unavailable, "HTTP #{response.code}: #{google_error_message(response)}"
      end
    rescue JSON::ParserError
      raise Unavailable, "invalid JSON from Gemini"
    end

    # 回應被截斷、被安全機制擋下或內容不是 JSON 時 data 為 nil（Google 仍已計費，頁數照扣）。
    def parse_success(payload)
      return Result.new(data: nil) unless payload.is_a?(Hash)
      text = payload.dig("candidates", 0, "content", "parts").to_a.filter_map { |p| p["text"] }.join
      Result.new(data: parse_data(text))
    end

    def parse_data(text)
      data = JSON.parse(text)
      data.is_a?(Hash) ? data : nil
    rescue JSON::ParserError
      nil
    end

    # 400 不一定是檔案的問題：我們送的設定（responseSchema、thinkingConfig）寫錯也是 INVALID_ARGUMENT，
    # 帳單 / 區域等前置條件沒設好是 FAILED_PRECONDITION。只有「INVALID_ARGUMENT、訊息明確指向檔案、
    # 且沒提到我們送出的設定」才算這張檔案無法辨識；其他（含分不出來的）一律當服務不可用（503），
    # 不讓設定錯誤被藏成「無法辨識」。
    FILE_PROBLEM = /image|document|pdf|file|mime|inline_?data|corrupt|decode|page/i
    CONFIG_PROBLEM = /schema|thinking|generation_?config|temperature|max_?output|enum|response_?mime|location|project|billing/i

    def classify_bad_request(response)
      status, message = google_error(response)
      if status == "INVALID_ARGUMENT" && message.match?(FILE_PROBLEM) && !message.match?(CONFIG_PROBLEM)
        raise InvalidDocument, message
      end
      raise Unavailable, "HTTP 400 #{status}: #{message}"
    end

    def google_error_message(response)
      google_error(response).last
    end

    # [error.status, error.message]
    def google_error(response)
      error = JSON.parse(response.body)["error"]
      error = {} unless error.is_a?(Hash)
      [ error["status"].to_s, error["message"].to_s ]
    rescue JSON::ParserError
      [ "", response.body.to_s.truncate(200) ]
    end
  end
end
