require "test_helper"

# 批次匯入憑證的測試共用：假 Gemini client、上傳檔案與請求。
#
# 每張憑證在頁面上畫成一個灰階方塊（由上到下排），灰階值就是這張憑證的代號：
# - 找位置：假 client 依頁面內容裡的 marker 回傳這頁有哪些灰階方塊，框就是方塊的位置。
# - 辨識：確認後後端實際轉圖、裁切，假 client 讀裁好的圖正中央的灰階，決定這張的回應。
# PDF 用 poppler 實際拆頁、轉圖；圖片用 libvips 畫。
module OcrBatchTestHelpers
  RECEIPT = { "document_type" => "receipt", "amount" => 100, "incurred_at" => "2026-10-15",
              "items" => [], "uncertain_fields" => [] }.freeze
  EMPTY = { "items" => [], "uncertain_fields" => [] }.freeze
  IMAGE_SIZE = 400
  PDF_SIZE   = 200

  # n 張憑證由上到下排的框（[ymin, xmin, ymax, xmax]，0–1000）
  def self.boxes(count)
    band = 1000 / [ count, 1 ].max
    Array.new(count) { |i| [ i * band + 10, 100, (i + 1) * band - 10, 900 ] }
  end

  # locate：marker => 這頁的灰階陣列（沒列到的 marker 為空白頁）、:unavailable、:invalid、{ sleep:, grays: }
  # recognize：灰階 => 行為（沒列到的辨識出一張收據，金額 = 灰階）；:empty、:unavailable、:invalid、
  #            { sleep: }（等幾秒再回收據）、字串 key 的 Hash（直接當作 Gemini 回的欄位）
  # 找位置的呼叫記在 calls（marker），辨識的呼叫記在 recognize_calls（灰階）。
  class FakeClient
    attr_reader :calls, :recognize_calls

    def initialize(locate, recognize = {})
      @locate = locate
      @recognize = recognize
      @grays = locate.values.flat_map { |b| b.is_a?(Hash) ? b[:grays] : Array(b) }.grep(Integer).uniq
      @calls = Queue.new
      @recognize_calls = Queue.new
    end

    def locate_receipts(bytes, _mime)
      marker = bytes[/marker-\w+/n]
      @calls << marker
      behavior = @locate.fetch(marker, [])
      case behavior
      when :unavailable then raise Ocr::GeminiClient::Unavailable, "down"
      when :invalid     then raise Ocr::GeminiClient::InvalidDocument, "bad page"
      when Hash
        sleep behavior[:sleep]
        boxes(behavior[:grays])
      else boxes(behavior)
      end
    end

    def recognize(bytes, _mime)
      image = Vips::Image.new_from_buffer(bytes, "")
      seen = image.getpoint(image.width / 2, image.height / 2).first
      gray = @grays.min_by { |g| (g - seen).abs }
      @recognize_calls << gray
      behavior = @recognize[gray]
      case behavior
      when :unavailable then raise Ocr::GeminiClient::Unavailable, "down"
      when :invalid     then raise Ocr::GeminiClient::InvalidDocument, "bad crop"
      when :empty       then result(EMPTY)
      when nil          then result(RECEIPT.merge("amount" => gray))
      else
        if behavior.key?(:sleep)
          sleep behavior[:sleep]
          result(RECEIPT.merge("amount" => gray))
        else
          result(behavior)
        end
      end
    end

    private

    def boxes(grays)
      result("receipts" => OcrBatchTestHelpers.boxes(grays.size).map { |box| { "box_2d" => box } })
    end

    def result(data)
      Ocr::GeminiClient::Result.new(data: data)
    end
  end

  # 找位置的結果寫不進去（鎖照常可寫）
  class FailingBatchCache < ActiveSupport::Cache::MemoryStore
    def write(name, *args, **options)
      name.to_s.start_with?("ocr_batch/") ? false : super
    end
  end

  def use_memory_cache
    # 測試環境的快取是 null_store（不存東西），這裡換成記憶體快取
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  def restore_cache
    Rails.cache = @original_cache
  end

  # 白底灰階方塊的 PNG；PNG 檔尾之後的內容不影響格式判斷，用來放 marker 與撐大檔案
  def png_upload(marker, grays = [], padding: 0)
    image = (Vips::Image.black(IMAGE_SIZE, IMAGE_SIZE) + 255).cast(:uchar)
    OcrBatchTestHelpers.boxes(grays.size).zip(grays).each do |(ymin, xmin, ymax, xmax), gray|
      image = image.draw_rect(gray, xmin * IMAGE_SIZE / 1000, ymin * IMAGE_SIZE / 1000,
                              (xmax - xmin) * IMAGE_SIZE / 1000, (ymax - ymin) * IMAGE_SIZE / 1000, fill: true)
    end
    content = image.pngsave_buffer + marker.b + ("\0" * padding).b
    Rack::Test::UploadedFile.new(StringIO.new(content), "image/png", original_filename: "#{marker}.png")
  end

  # pages：[ [marker, 灰階陣列], ... ]
  def pdf_upload(pages)
    Rack::Test::UploadedFile.new(StringIO.new(pdf(pages)), "application/pdf", original_filename: "收據.pdf")
  end

  # 每頁內容放一個 marker（註解）與灰階方塊的最小 PDF（pdfinfo / pdfseparate / pdftoppm 讀得懂）
  def pdf(pages)
    objects = [ "<< /Type /Catalog /Pages 2 0 R >>",
                "<< /Type /Pages /Kids [#{pages.each_index.map { |i| "#{3 + i * 2} 0 R" }.join(' ')}] /Count #{pages.size} >>" ]
    scale = PDF_SIZE / 1000.0
    pages.each_with_index do |(marker, grays), i|
      grays = Array(grays)
      content = +"% #{marker}\n"
      OcrBatchTestHelpers.boxes(grays.size).zip(grays).each do |(ymin, xmin, ymax, xmax), gray|
        content << format("%.4f g %.2f %.2f %.2f %.2f re f\n", gray / 255.0, xmin * scale, PDF_SIZE - ymax * scale,
                          (xmax - xmin) * scale, (ymax - ymin) * scale)
      end
      objects << "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{PDF_SIZE} #{PDF_SIZE}] /Contents #{4 + i * 2} 0 R >>"
      objects << "<< /Length #{content.bytesize} >>\nstream\n#{content}endstream"
    end
    out = +"%PDF-1.4\n"
    offsets = objects.each_with_index.map do |object, i|
      offset = out.bytesize
      out << "#{i + 1} 0 obj\n#{object}\nendobj\n"
      offset
    end
    xref = out.bytesize
    out << "xref\n0 #{objects.size + 1}\n0000000000 65535 f \n"
    offsets.each { |offset| out << format("%010d 00000 n \n", offset) }
    out << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n"
    out.b
  end

  def post_batch(client, uploads, user: @admin, role: "expense")
    @client = client
    Ocr::GeminiClient.stub_from_env(client) do
      post "/api/ocr/batch", params: { role: role, files: uploads }, headers: auth_headers(user)
    end
    response.parsed_body
  end

  def confirm(token, page_ids, user: @admin, client: @client)
    Ocr::GeminiClient.stub_from_env(client) do
      post "/api/ocr/batch/#{token}/confirm", params: { page_ids: page_ids }, headers: auth_headers(user), as: :json
    end
    response.parsed_body
  end
end

# 批次匯入憑證：找位置不扣次、確認後逐張辨識並扣辨識出內容的張數、取消不扣次、暫存綁本人本公司、
# 權限與上限、期限、同公司同時一批。
class OcrBatchTest < ActionDispatch::IntegrationTest
  include OcrBatchTestHelpers

  setup do
    @company = create_company(name: "甲公司")
    @admin   = create_user(company: @company, role: "admin")
    create_account(company: @company)
    @company.update!(ocr_monthly_quota: 20, ocr_monthly_used: 0)
    use_memory_cache
  end

  teardown do
    restore_cache
  end

  # ─── 找位置與確認 ─────────────────────────────

  test "上傳只找位置、不扣次；確認後逐張辨識，只扣辨識出內容的張數，回內容與所在頁的檔案" do
    client = FakeClient.new({ "marker-p1" => [ 40, 80 ], "marker-img" => [ 120 ] }, { 80 => :empty })
    body = post_batch(client, [ pdf_upload([ [ "marker-p1", [ 40, 80 ] ], [ "marker-p2", [] ] ]),
                               png_upload("marker-img", [ 120 ]) ])

    assert_response :ok
    assert_equal 3, body["receipt_count"]
    assert_equal [ [ "0-1", 1, 2 ], [ "0-2", 2, 0 ], [ "1-1", 1, 1 ] ],
      body["pages"].map { |p| p.values_at("page_id", "page_number", "receipt_count") }
    assert_equal 3, client.calls.size
    assert_equal 0, client.recognize_calls.size
    assert_equal 0, @company.reload.ocr_monthly_used

    body = confirm(body["token"], %w[0-1 0-2 1-1])
    assert_response :ok
    assert_equal 3, client.recognize_calls.size
    assert_equal 2, @company.reload.ocr_monthly_used
    assert_equal 2, body.dig("quota", "used")
    assert_equal [ [ "0-1", 40 ], [ "1-1", 120 ] ], body["receipts"].map { |r| [ r["page_id"], r.dig("result", "merged", "amount") ] }
    assert_equal [ "第 1 個檔案第 1 頁第 2 張未辨識出內容，未扣次" ], body["warnings"]
    # 附件每頁一份，只列所選、有辨識出內容的頁
    assert_equal [ "0-1", "1-1" ], body["pages"].map { |p| p["page_id"] }
    attachment = body["pages"].first["attachment"]
    assert_equal [ "收據_p1.pdf", "application/pdf" ], attachment.values_at("filename", "mime_type")
    # 附件存成暫存檔，回 id 與讀取網址
    blob = ActiveStorage::Blob.find(attachment["id"])
    assert_equal "marker-p1", blob.download[/marker-\w+/]
    assert_equal attachment["byte_size"], blob.byte_size
  end

  test "全部頁都找不到憑證 → 422 ocr_no_result，不發 token、不扣次" do
    post_batch(FakeClient.new({}), [ png_upload("marker-x") ])
    assert_response :unprocessable_content
    assert_equal "ocr_no_result", response.parsed_body["code"]
    assert_nil response.parsed_body["token"]
    assert_equal 0, @company.reload.ocr_monthly_used
  end

  test "確認後全部辨識不出內容 → 200、receipts 為空、不扣次，暫存照常刪掉" do
    client = FakeClient.new({ "marker-a" => [ 40, 80 ] }, { 40 => :empty, 80 => :empty })
    token = post_batch(client, [ png_upload("marker-a", [ 40, 80 ]) ])["token"]

    body = confirm(token, %w[0-1])
    assert_response :ok
    assert_equal [ [], [], 0 ], [ body["receipts"], body["pages"], body.dig("quota", "used") ]
    assert_equal [ "第 1 個檔案未辨識出內容，未扣次" ], body["warnings"]
    assert_equal 0, @company.reload.ocr_monthly_used

    confirm(token, %w[0-1])
    assert_response :not_found
  end

  test "取消不扣次，之後也不能確認" do
    body = post_batch(FakeClient.new({ "marker-a" => [ 40 ] }), [ png_upload("marker-a", [ 40 ]) ])
    delete "/api/ocr/batch/#{body['token']}", headers: auth_headers(@admin)
    assert_response :no_content

    confirm(body["token"], %w[0-1])
    assert_response :not_found
    assert_equal 0, @company.reload.ocr_monthly_used
    assert_equal 0, @client.recognize_calls.size

    delete "/api/ocr/batch/#{body['token']}", headers: auth_headers(@admin)
    assert_response :no_content
  end

  test "次數不夠所選頁的張數 → 429 quota_insufficient 附 required，不辨識、暫存保留可改選；剩 0 → quota_exhausted" do
    client = FakeClient.new({ "marker-a" => [ 40, 80, 120 ], "marker-b" => [ 160 ] })
    body = post_batch(client, [ png_upload("marker-a", [ 40, 80, 120 ]), png_upload("marker-b", [ 160 ]) ])
    @company.update!(ocr_monthly_used: 18)

    confirm(body["token"], %w[0-1 1-1])
    assert_response :too_many_requests
    assert_equal [ "quota_insufficient", 4 ], response.parsed_body.values_at("code", "required")
    assert_equal 0, client.recognize_calls.size
    assert_equal 18, @company.reload.ocr_monthly_used

    confirm(body["token"], %w[1-1])
    assert_response :ok
    assert_equal 19, @company.reload.ocr_monthly_used

    body = post_batch(FakeClient.new({ "marker-a" => [ 40 ] }), [ png_upload("marker-a", [ 40 ]) ])
    @company.update!(ocr_monthly_used: 20)
    confirm(body["token"], %w[0-1])
    assert_response :too_many_requests
    assert_equal "quota_exhausted", response.parsed_body["code"]
  end

  test "剩 0 次時上傳就擋，不送 Gemini" do
    @company.update!(ocr_monthly_used: 20)
    client = FakeClient.new({ "marker-a" => [ 40 ] })
    post_batch(client, [ png_upload("marker-a", [ 40 ]) ])
    assert_response :too_many_requests
    assert_equal "quota_exhausted", response.parsed_body["code"]
    assert_equal 0, client.calls.size
  end

  test "選的頁有誤或沒有憑證 → 400" do
    body = post_batch(FakeClient.new({ "marker-p1" => [ 40 ] }), [ pdf_upload([ [ "marker-p1", [ 40 ] ], [ "marker-p2", [] ] ]) ])
    [ [], %w[9-9], %w[0-2] ].each do |ids|
      confirm(body["token"], ids)
      assert_response :bad_request
      assert_equal "invalid_page_ids", response.parsed_body["code"]
    end
    assert_equal 0, @company.reload.ocr_monthly_used
  end

  # ─── 暫存 ─────────────────────────────

  test "重複確認、過期 → 404 batch_expired" do
    body = post_batch(FakeClient.new({ "marker-a" => [ 40 ] }), [ png_upload("marker-a", [ 40 ]) ])
    confirm(body["token"], %w[0-1])
    assert_response :ok
    confirm(body["token"], %w[0-1])
    assert_response :not_found
    assert_equal "batch_expired", response.parsed_body["code"]

    body = post_batch(FakeClient.new({ "marker-a" => [ 40 ] }), [ png_upload("marker-a", [ 40 ]) ])
    travel 31.minutes do
      confirm(body["token"], %w[0-1])
    end
    assert_response :not_found
    assert_equal 1, @company.reload.ocr_monthly_used
  end

  test "別家公司或同公司別人的 token 查不到，也刪不掉" do
    body = post_batch(FakeClient.new({ "marker-a" => [ 40 ] }), [ png_upload("marker-a", [ 40 ]) ])
    other_admin = create_user(company: create_account(company: create_company(name: "乙公司")).company, role: "admin")
    same_company_admin = create_user(company: @company, role: "admin")

    [ other_admin, same_company_admin ].each do |user|
      confirm(body["token"], %w[0-1], user: user)
      assert_response :not_found
      delete "/api/ocr/batch/#{body['token']}", headers: auth_headers(user)
    end

    confirm(body["token"], %w[0-1])
    assert_response :ok
  end

  # ─── 上限 ─────────────────────────────

  test "超過 5 個檔案、單檔 20MB、合計 5 頁 → 退回，不送 Gemini" do
    client = FakeClient.new({ "marker-a" => [ 40 ] })
    post_batch(client, Array.new(6) { png_upload("marker-a") })
    assert_response :bad_request
    assert_equal "too_many_files", response.parsed_body["code"]

    post_batch(client, [ png_upload("marker-a", padding: 20 * 1024 * 1024 + 1) ])
    assert_response :content_too_large
    assert_equal "file_too_large", response.parsed_body["code"]

    post_batch(client, [ pdf_upload(Array.new(4) { |i| [ "marker-#{i}", [] ] }), pdf_upload([ [ "marker-4", [] ], [ "marker-5", [] ] ]) ])
    assert_response :bad_request
    assert_equal "too_many_pages", response.parsed_body["code"]
    assert_equal "最多 5 頁（目前 6 頁）", response.parsed_body["message"]
    assert_equal 0, client.calls.size
  end

  test "每頁最多 10 張，超過的捨棄並提醒；5 頁剛好 50 張不觸發整批上限" do
    grays = Array.new(12) { |i| 20 + i * 15 }
    client = FakeClient.new((0..4).to_h { |i| [ "marker-#{i}", grays ] })
    body = post_batch(client, [ pdf_upload(Array.new(4) { |i| [ "marker-#{i}", [] ] }), png_upload("marker-4") ])

    assert_response :ok
    assert_equal 50, body["receipt_count"]
    assert_equal [ 10, 10, 10, 10, 10 ], body["pages"].map { |p| p["receipt_count"] }
    assert_includes body["warnings"], "第 1 個檔案第 1 頁超過 10 張憑證，只取前 10 張"
    assert_not_includes body["warnings"], "憑證超過 50 張，只取前 50 張"
  end

  test "整批超過上限張數 → 依檔案、頁碼順序取前面的並提醒" do
    client = FakeClient.new({ "marker-p1" => [ 40, 80, 120 ], "marker-p2" => [ 40, 80, 120 ] })
    body = swap_const(Api::OcrBatchesController, :MAX_RECEIPTS, 4) do
      post_batch(client, [ pdf_upload([ [ "marker-p1", [] ], [ "marker-p2", [] ] ]) ])
    end

    assert_response :ok
    assert_equal 4, body["receipt_count"]
    assert_equal [ 3, 1 ], body["pages"].map { |p| p["receipt_count"] }
    assert_equal [ "憑證超過 4 張，只取前 4 張" ], body["warnings"]
  end

  test "單頁超過 5MB：憑證照樣帶出，附件為 null 並提醒自行補上" do
    body = post_batch(FakeClient.new({ "marker-a" => [ 40 ] }), [ png_upload("marker-a", [ 40 ], padding: 6 * 1024 * 1024) ])
    assert_response :ok
    body = confirm(body["token"], %w[0-1])
    assert_equal 1, body["receipts"].size
    assert_nil body["pages"].sole["attachment"]
    assert_equal [ "第 1 個檔案的檔案超過 5MB，未附上憑證檔，請自行補上" ], body["warnings"]
  end

  # ─── 權限 ─────────────────────────────

  test "員工不可使用" do
    employee = create_user(company: @company)
    client = FakeClient.new({ "marker-a" => [ 40 ] })
    post_batch(client, [ png_upload("marker-a", [ 40 ]) ], user: employee)
    assert_response :forbidden
    confirm("x" * 32, %w[0-1], user: employee)
    assert_response :forbidden
    delete "/api/ocr/batch/#{'x' * 32}", headers: auth_headers(employee)
    assert_response :forbidden
    assert_equal 0, client.calls.size
  end

  test "未登入 → 401" do
    post "/api/ocr/batch", params: { role: "expense", files: [ png_upload("marker-a") ] }
    assert_response :unauthorized
    post "/api/ocr/batch/#{'x' * 32}/confirm", params: { page_ids: %w[0-1] }, as: :json
    assert_response :unauthorized
  end

  # ─── 公司沒有帳戶 ─────────────────────────────

  test "公司沒有帳戶（帳戶在垃圾桶也算）：上傳就擋、不找位置；上傳後帳戶被刪，確認也擋，不辨識、不扣次" do
    client = FakeClient.new({ "marker-a" => [ 40 ] })
    token = post_batch(client, [ png_upload("marker-a", [ 40 ]) ])["token"]
    assert_response :ok
    @company.accounts.each(&:discard!)

    body = confirm(token, %w[0-1])
    assert_response :unprocessable_content
    assert_equal "NO_ACCOUNTS", body["code"]
    assert_equal "公司還沒有帳戶，請先到帳戶設定建立", body["message"]
    assert_equal 0, client.recognize_calls.size

    post_batch(client, [ png_upload("marker-a", [ 40 ]) ])
    assert_response :unprocessable_content
    assert_equal "NO_ACCOUNTS", response.parsed_body["code"]
    assert_equal 1, client.calls.size
    assert_equal 0, @company.reload.ocr_monthly_used
  end

  # ─── Google 無法使用、回 400 ─────────────────────────────

  test "找位置時某頁 Google 無法使用 → 整批 503、不發 token、其他頁不再送出，之後可以再傳" do
    markers = Array.new(5) { |i| "marker-#{i}" }
    behaviors = markers.to_h { |m| [ m, { sleep: 0.5, grays: [ 40 ] } ] }.merge("marker-0" => :unavailable)
    client = FakeClient.new(behaviors)
    # 5 頁一輪就全部送出，看不出「其他頁不再送出」，這裡把並行數降成 2
    swap_const(Ocr::BatchRecognizer, :THREADS, 2) { post_batch(client, [ pdf_upload(markers.map { |m| [ m, [] ] }) ]) }

    assert_response :service_unavailable
    assert_equal "ocr_unavailable", response.parsed_body["code"]
    assert_operator client.calls.size, :<=, 2
    assert_equal 0, @company.reload.ocr_monthly_used

    post_batch(FakeClient.new({ "marker-a" => [ 40 ] }), [ png_upload("marker-a", [ 40 ]) ])
    assert_response :ok
  end

  test "確認時 Google 無法使用 → 503、不扣次、暫存保留，再確認一次可以成功" do
    client = FakeClient.new({ "marker-a" => [ 40, 80 ] }, { 80 => :unavailable })
    token = post_batch(client, [ png_upload("marker-a", [ 40, 80 ]) ])["token"]

    confirm(token, %w[0-1])
    assert_response :service_unavailable
    assert_equal "ocr_unavailable", response.parsed_body["code"]
    assert_equal 0, @company.reload.ocr_monthly_used
    assert_nil Rails.cache.read("ocr_batch_lock/#{@company.id}")

    body = confirm(token, %w[0-1], client: FakeClient.new({ "marker-a" => [ 40, 80 ] }))
    assert_response :ok
    assert_equal [ 40, 80 ], body["receipts"].map { |r| r.dig("result", "merged", "amount") }
    assert_equal 2, @company.reload.ocr_monthly_used
  end

  test "找位置時某頁 Google 回 400 → 該頁略過並提醒，其他頁照常" do
    client = FakeClient.new({ "marker-p1" => [ 40 ], "marker-p2" => :invalid })
    body = post_batch(client, [ pdf_upload([ [ "marker-p1", [ 40 ] ], [ "marker-p2", [] ] ]) ])
    assert_response :ok
    assert_equal [ 1, 0 ], body["pages"].map { |p| p["receipt_count"] }
    assert_equal [ "第 1 個檔案第 2 頁無法辨識，已略過" ], body["warnings"]
  end

  test "確認時某張 Google 回 400 → 那張不扣次並提醒，其他張照常" do
    client = FakeClient.new({ "marker-p1" => [ 40, 80 ] }, { 40 => :invalid })
    body = post_batch(client, [ pdf_upload([ [ "marker-p1", [ 40, 80 ] ] ]) ])

    body = confirm(body["token"], %w[0-1])
    assert_response :ok
    assert_equal [ 80 ], body["receipts"].map { |r| r.dig("result", "merged", "amount") }
    assert_equal [ "第 1 個檔案第 1 頁第 1 張無法辨識，未扣次" ], body["warnings"]
    assert_equal 1, @company.reload.ocr_monthly_used
  end

  test "暫存寫入失敗 → 503，鎖照樣釋放" do
    Rails.cache = FailingBatchCache.new

    post_batch(FakeClient.new({ "marker-a" => [ 40 ] }), [ png_upload("marker-a", [ 40 ]) ])
    assert_response :service_unavailable
    assert_nil Rails.cache.read("ocr_batch_lock/#{@company.id}")
  end

  test "每張裁好的圖各自解 QR，有電子發票時以 QR 為準" do
    gemini = RECEIPT.merge("document_type" => "invoice", "invoice_prefix" => "AB", "invoice_digits" => "12345678", "amount" => 999)
    qr = { invoice_prefix: "AB", invoice_digits: "12345678", incurred_at: "2026-10-01", pre_tax_amt: 1000, tax_amt: 50,
           amount: 1050, buyer_tax_id: nil, seller_tax_id: "04595257", page: 0, items: [] }
    body = post_batch(FakeClient.new({ "marker-a" => [ 40 ] }, { 40 => gemini }), [ png_upload("marker-a", [ 40 ]) ])

    body = stub_invoice_qr([ qr ]) { confirm(body["token"], %w[0-1]) }
    merged = body["receipts"].sole.dig("result", "merged")
    assert_equal [ 1050, "2026-10-01", "04595257" ], merged.values_at("amount", "incurred_at", "counterparty_tax_id")
  end

  # ─── 收入 ─────────────────────────────

  test "收入：確認時照上傳的 role 對應，客戶 = 買方，QR 的買方統編帶到對方欄位" do
    gemini = RECEIPT.merge("document_type" => "invoice", "invoice_prefix" => "AB", "invoice_digits" => "12345678",
                           "buyer_name" => "鉅邦科技有限公司", "buyer_tax_id" => "12345675",
                           "seller_name" => "甲公司", "seller_tax_id" => "04595257")
    qr = { invoice_prefix: "AB", invoice_digits: "12345678", incurred_at: "2026-10-01", pre_tax_amt: 1000, tax_amt: 50,
           amount: 1050, buyer_tax_id: "12345675", seller_tax_id: "04595257", page: 0, items: [] }
    body = post_batch(FakeClient.new({ "marker-a" => [ 40 ] }, { 40 => gemini }), [ png_upload("marker-a", [ 40 ]) ], role: "income")
    assert_response :ok

    body = stub_invoice_qr([ qr ]) { confirm(body["token"], %w[0-1]) }
    assert_response :ok
    merged = body["receipts"].sole.dig("result", "merged")
    assert_equal [ "鉅邦科技有限公司", "12345675", "04595257" ],
      merged.values_at("counterparty_name", "counterparty_tax_id", "our_tax_id")
    assert_equal 1, @company.reload.ocr_monthly_used
  end

  test "收入與支出共用次數上限與同公司一批的規則；代墊款不開放" do
    @company.update!(ocr_monthly_used: 20)
    post_batch(FakeClient.new({ "marker-a" => [ 40 ] }), [ png_upload("marker-a", [ 40 ]) ], role: "income")
    assert_response :too_many_requests
    assert_equal "quota_exhausted", response.parsed_body["code"]

    @company.update!(ocr_monthly_used: 0)
    client = FakeClient.new({ "marker-a" => [ 40 ] })
    body = post_batch(client, [ png_upload("marker-a", [ 40 ]) ], role: "reimbursement")
    assert_response :bad_request
    assert_equal "invalid_role", body["code"]
    assert_equal 0, client.calls.size
  end

  # ─── 期限、同時一批 ─────────────────────────────

  test "找位置期限到了還沒找完的頁當作逾時：0 張並提醒，已完成的頁照常" do
    client = FakeClient.new({ "marker-fast" => [ 40 ], "marker-slow" => { sleep: 5, grays: [ 80 ] } })
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    body = swap_const(Ocr::BatchRecognizer, :TIME_LIMIT, 0.5) do
      post_batch(client, [ png_upload("marker-fast", [ 40 ]), png_upload("marker-slow", [ 80 ]) ])
    end

    assert_response :ok
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 3
    assert_equal [ 1, 0 ], body["pages"].map { |p| p["receipt_count"] }
    assert_equal [ "第 2 個檔案辨識逾時，未扣次，可重新上傳該頁" ], body["warnings"]

    swap_const(Ocr::BatchRecognizer, :TIME_LIMIT, 0.2) do
      post_batch(FakeClient.new({ "marker-slow" => { sleep: 5, grays: [ 80 ] } }), [ png_upload("marker-slow", [ 80 ]) ])
    end
    assert_response :unprocessable_content
    assert_equal "ocr_no_result", response.parsed_body["code"]
  end

  test "確認後期限到了還沒辨識完的憑證不扣次並提醒，已完成的照常" do
    client = FakeClient.new({ "marker-a" => [ 40, 160 ] }, { 160 => { sleep: 5 } })
    token = post_batch(client, [ png_upload("marker-a", [ 40, 160 ]) ])["token"]

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    body = swap_const(Ocr::BatchRecognizer, :TIME_LIMIT, 1) { confirm(token, %w[0-1]) }
    assert_response :ok
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 4
    assert_equal [ 40 ], body["receipts"].map { |r| r.dig("result", "merged", "amount") }
    assert_equal [ "第 1 個檔案第 2 張辨識逾時，未扣次，可重新上傳該頁" ], body["warnings"]
    assert_equal 1, @company.reload.ocr_monthly_used
  end

  test "同公司已有一批在辨識 → 上傳、確認都回 409 batch_in_progress，不送 Gemini；鎖會自動過期，別家公司不受影響" do
    client = FakeClient.new({ "marker-a" => [ 40 ] })
    token = post_batch(client, [ png_upload("marker-a", [ 40 ]) ])["token"]
    Rails.cache.write("ocr_batch_lock/#{@company.id}", "另一個請求", expires_in: Api::OcrBatchesController::BATCH_LOCK_TTL)

    post_batch(client, [ png_upload("marker-a", [ 40 ]) ])
    assert_response :conflict
    assert_equal [ "batch_in_progress", "上一批憑證還在辨識中，請稍候再試" ], response.parsed_body.values_at("code", "message")
    confirm(token, %w[0-1])
    assert_response :conflict
    assert_equal 1, client.calls.size
    assert_equal 0, client.recognize_calls.size

    other_admin = create_user(company: create_account(company: create_company(name: "乙公司")).company, role: "admin")
    post_batch(client, [ png_upload("marker-a", [ 40 ]) ], user: other_admin)
    assert_response :ok

    travel Api::OcrBatchesController::BATCH_LOCK_TTL + 1.second do
      confirm(token, %w[0-1])
    end
    assert_response :ok
  end

  private

  def swap_const(klass, name, value)
    original = klass.const_get(name)
    klass.send(:remove_const, name)
    klass.const_set(name, value)
    yield
  ensure
    klass.send(:remove_const, name)
    klass.const_set(name, original)
  end

  def stub_invoice_qr(invoices)
    Ocr::InvoiceQr.singleton_class.alias_method(:__call, :call)
    Ocr::InvoiceQr.singleton_class.define_method(:call) { |_codes| invoices }
    yield
  ensure
    Ocr::InvoiceQr.singleton_class.alias_method(:call, :__call)
    Ocr::InvoiceQr.singleton_class.remove_method(:__call)
  end
end

# 框的整理與裁切範圍：夾在圖內，不會超出邊界或變成 0 像素。
class OcrBatchCropTest < ActiveSupport::TestCase
  test "框夾在 0–1000、顛倒的對調，格式不對或太小的不算" do
    normalize = ->(box) { Ocr::BatchRecognizer.normalize_box(box) }
    assert_equal [ 100, 200, 300, 400 ], normalize.([ 100, 200, 300, 400 ])
    assert_equal [ 0, 0, 1000, 1000 ], normalize.([ -50, -10, 1200, 1001 ])
    assert_equal [ 100, 200, 300, 400 ], normalize.([ 300, 400, 100, 200 ])
    assert_equal [ 100, 200, 300, 400 ], normalize.([ 100.4, 199.6, 300, 400 ])
    assert_nil normalize.([ 100, 200, 105, 400 ])
    assert_nil normalize.([ 100, 200, 300 ])
    assert_nil normalize.([ 100, "200", 300, 400 ])
    assert_nil normalize.(nil)
  end

  test "裁切範圍四周多留 3% 的邊，夾在圖內" do
    region = ->(box, width, height) { Ocr::BatchRecognizer.crop_region(box, width, height) }
    assert_equal [ 170, 70, 260, 260 ], region.([ 100, 200, 300, 400 ], 1000, 1000)
    assert_equal [ 0, 0, 400, 300 ], region.([ 0, 0, 1000, 1000 ], 400, 300)
    # 貼著右下角的小框：不超出圖、寬高至少 1 像素
    assert_equal [ 6, 2, 1, 1 ], region.([ 990, 990, 1000, 1000 ], 7, 3)
    left, top, width, height = region.([ 0, 980, 20, 1000 ], 3600, 2546)
    assert_equal [ 3420, 0 ], [ left, top ]
    assert_operator left + width, :<=, 3600
    assert_operator top + height, :<=, 2546
  end
end

# 同一批同時確認兩次：要用真的資料庫交易與兩條連線，不能包在測試交易裡。
class OcrBatchConcurrencyTest < ActionDispatch::IntegrationTest
  include OcrBatchTestHelpers

  self.use_transactional_tests = false

  setup do
    @company = create_company(name: "並行公司")
    @admin   = create_user(company: @company, role: "admin")
    create_account(company: @company)
    @company.update!(ocr_monthly_quota: 20, ocr_monthly_used: 0)
    use_memory_cache
  end

  teardown do
    restore_cache
    ActiveStorage::Blob.where(company_id: @company.id).find_each(&:purge)
    User.where(company_id: @company.id).delete_all
    @company.destroy!
  end

  test "同一批同時確認兩次，只有一次成功、只扣一次" do
    client = FakeClient.new({ "marker-a" => [ 40, 80, 120 ] })
    token = post_batch(client, [ png_upload("marker-a", [ 40, 80, 120 ]) ])["token"]

    statuses = Ocr::GeminiClient.stub_from_env(client) do
      Array.new(2) do
        Thread.new do
          session = ActionDispatch::Integration::Session.new(Rails.application)
          session.post "/api/ocr/batch/#{token}/confirm", params: { page_ids: %w[0-1] },
                                                         headers: auth_headers(@admin), as: :json
          session.response.status
        end
      end.map(&:value)
    end

    # 後到的拿不到鎖（409），或前一個已確認完、暫存已刪（404）
    assert_equal 200, statuses.min
    assert_includes [ 404, 409 ], statuses.max
    assert_equal 3, @company.reload.ocr_monthly_used
  end
end
