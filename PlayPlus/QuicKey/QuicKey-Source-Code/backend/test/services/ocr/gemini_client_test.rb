require "test_helper"

# Google 回 400 時只有「INVALID_ARGUMENT 且明確是檔案問題」才算這張檔案無法辨識；其他一律 503（不藏設定錯誤）。
class Ocr::GeminiClientTest < ActiveSupport::TestCase
  def bad_request(status, message)
    response = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
    body = { error: { code: 400, status: status, message: message } }.to_json
    response.define_singleton_method(:body) { body }
    response
  end

  def classify(status, message)
    client = Ocr::GeminiClient.new(project_id: "p", location: "global", credentials_path: "x")
    client.send(:handle_response, bad_request(status, message))
  end

  test "INVALID_ARGUMENT 且訊息指向檔案 → InvalidDocument" do
    assert_raises(Ocr::GeminiClient::InvalidDocument) { classify("INVALID_ARGUMENT", "Unable to process input image. The document has no pages.") }
  end

  test "INVALID_ARGUMENT 但指向我們送的設定 → Unavailable" do
    assert_raises(Ocr::GeminiClient::Unavailable) { classify("INVALID_ARGUMENT", "Invalid value at 'generation_config.thinking_config.thinking_level'") }
    assert_raises(Ocr::GeminiClient::Unavailable) { classify("INVALID_ARGUMENT", "Invalid JSON payload: response_schema enum mismatch for the image field") }
  end

  test "INVALID_ARGUMENT 但分不出原因 → Unavailable" do
    assert_raises(Ocr::GeminiClient::Unavailable) { classify("INVALID_ARGUMENT", "Request contains an invalid argument.") }
  end

  test "FAILED_PRECONDITION 等其他狀態 → Unavailable" do
    assert_raises(Ocr::GeminiClient::Unavailable) { classify("FAILED_PRECONDITION", "Billing account for project is not found. image") }
  end

  test "訊息提到 model 但指向檔案（例如 PDF 超過模型頁數上限）→ InvalidDocument" do
    assert_raises(Ocr::GeminiClient::InvalidDocument) { classify("INVALID_ARGUMENT", "The PDF exceeds the page limit supported by this model") }
  end

  test "回應不是 Hash 時不丟錯，當作沒有結果" do
    client = Ocr::GeminiClient.new(project_id: "p", location: "global", credentials_path: "x")
    result = client.send(:parse_success, [ 1 ])
    assert_nil result.data
  end
end
