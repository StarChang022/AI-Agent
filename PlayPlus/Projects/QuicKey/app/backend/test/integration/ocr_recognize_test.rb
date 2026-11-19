require "test_helper"

# OCR 辨識：按頁扣次與公司間隔離。Gemini 以假 client 取代，不打 Google。
class OcrRecognizeTest < ActionDispatch::IntegrationTest
  PNG = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")

  FakeClient = Struct.new(:responses) do
    def recognize(_bytes, _mime)
      responses.shift
    end
  end

  setup do
    @company = create_company(name: "甲公司")
    @user    = create_user(company: @company, role: "admin")
    @other   = create_company(name: "乙公司")
    @other_user = create_user(company: @other, role: "admin")
  end

  def result(data:)
    Ocr::GeminiClient::Result.new(data: data)
  end

  def recognize(user, *responses, files: 1)
    client = FakeClient.new(responses)
    Ocr::GeminiClient.stub_from_env(client) do
      ids = Array.new(files) { upload(PNG, "image/png", "a.png", user: user).id }
      post "/api/ocr/recognize", params: { role: "expense", attachment_ids: ids }, headers: auth_headers(user)
    end
  end

  test "辨識成功扣 1 次" do
    recognize(@user, result(data: { "amount" => 100, "incurred_at" => "2026-10-15", "items" => [], "uncertain_fields" => [] }))
    assert_response :ok
    assert_equal 1, @company.reload.ocr_monthly_used
  end

  test "抽不出欄位（422）照扣次" do
    recognize(@user, result(data: { "items" => [], "uncertain_fields" => [] }))
    assert_response :unprocessable_content
    assert_equal 1, @company.reload.ocr_monthly_used
  end

  test "回應被截斷（沒有資料）照扣次" do
    recognize(@user, result(data: nil))
    assert_response :unprocessable_content
    assert_equal 1, @company.reload.ocr_monthly_used
  end

  test "多檔按張數扣次" do
    data = { "amount" => 100, "items" => [], "uncertain_fields" => [] }
    recognize(@user, result(data: data), result(data: data), files: 2)
    assert_response :ok
    assert_equal 2, @company.reload.ocr_monthly_used
  end

  test "次數只扣呼叫者的公司" do
    recognize(@user, result(data: { "amount" => 100, "items" => [], "uncertain_fields" => [] }))
    assert_equal 1, @company.reload.ocr_monthly_used
    assert_equal 0, @other.reload.ocr_monthly_used
  end

  test "Google 無法使用時回 503 且不扣次" do
    client = Object.new
    client.define_singleton_method(:recognize) { |*| raise Ocr::GeminiClient::Unavailable, "down" }
    Ocr::GeminiClient.stub_from_env(client) do
      post "/api/ocr/recognize", params: { role: "expense", attachment_ids: [ upload(PNG, "image/png", "a.png").id ] },
                                 headers: auth_headers(@user)
    end
    assert_response :service_unavailable
    assert_equal 0, @company.reload.ocr_monthly_used
  end

  PDF = "%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n".b

  # 辨識的對象是已上傳的圖檔（暫存檔）
  def upload(content, mime, name, user: @user)
    AttachmentFiles.create_blob!(io: StringIO.new(content), filename: name, content_type: mime, user: user)
  end

  def post_files(user, uploads, client)
    Ocr::GeminiClient.stub_from_env(client) do
      post "/api/ocr/recognize", params: { role: "expense", attachment_ids: uploads.map(&:id) }, headers: auth_headers(user)
    end
  end

  def exploding_client
    client = Object.new
    client.define_singleton_method(:recognize) { |*| raise "不該呼叫 Gemini" }
    client
  end

  test "剩餘次數不夠本次總頁數：回 429 quota_insufficient，不辨識、不扣次、不記用量" do
    @company.update!(ocr_monthly_quota: 5, ocr_monthly_used: 4)
    post_files(@user, [ upload(PNG, "image/png", "a.png"), upload(PNG, "image/png", "b.png") ], exploding_client)

    assert_response :too_many_requests
    body = response.parsed_body
    assert_equal "quota_insufficient", body["code"]
    assert_equal 2, body["required"]
    assert_equal 1, body.dig("quota", "monthly_remaining")
    assert_equal 4, @company.reload.ocr_monthly_used
  end

  test "PDF 按實際頁數算需要的次數" do
    @company.update!(ocr_monthly_quota: 5, ocr_monthly_used: 2)
    pages = Ocr::PdfPages
    pages.singleton_class.alias_method(:__count, :count)
    pages.singleton_class.define_method(:count) { |_| 4 }
    begin
      post_files(@user, [ upload(PDF, "application/pdf", "a.pdf") ], exploding_client)
    ensure
      pages.singleton_class.alias_method(:count, :__count)
      pages.singleton_class.remove_method(:__count)
    end

    assert_response :too_many_requests
    assert_equal "quota_insufficient", response.parsed_body["code"]
    assert_equal 4, response.parsed_body["required"]
  end

  test "剩餘次數是 0 時回 quota_exhausted，沒有 required" do
    @company.update!(ocr_monthly_quota: 5, ocr_monthly_used: 5)
    post_files(@user, [ upload(PNG, "image/png", "a.png") ], exploding_client)

    assert_response :too_many_requests
    assert_equal "quota_exhausted", response.parsed_body["code"]
    assert_nil response.parsed_body["required"]
  end

  test "剩 0 次時先回 429，不做轉檔與數頁（壞檔也一樣）" do
    @company.update!(ocr_monthly_quota: 5, ocr_monthly_used: 5)
    pages = Ocr::PdfPages
    pages.singleton_class.alias_method(:__count, :count)
    pages.singleton_class.define_method(:count) { |_| raise "不該數頁" }
    begin
      post_files(@user, [ upload(PDF, "application/pdf", "a.pdf") ], exploding_client)
    ensure
      pages.singleton_class.alias_method(:count, :__count)
      pages.singleton_class.remove_method(:__count)
    end
    assert_response :too_many_requests
    assert_equal "quota_exhausted", response.parsed_body["code"]
  end

  test "剛好夠用就辨識並扣次" do
    @company.update!(ocr_monthly_quota: 5, ocr_monthly_used: 4)
    recognize(@user, result(data: { "amount" => 100, "items" => [], "uncertain_fields" => [] }))
    assert_response :ok
    assert_equal 5, @company.reload.ocr_monthly_used
  end

  test "找不到 pdfinfo 回 503，不默默當 1 頁" do
    old = ENV["PATH"]
    ENV["PATH"] = ""
    begin
      post_files(@user, [ upload(PDF, "application/pdf", "a.pdf") ], exploding_client)
    ensure
      ENV["PATH"] = old
    end
    assert_response :service_unavailable
    assert_equal 0, @company.reload.ocr_monthly_used
  end
end
