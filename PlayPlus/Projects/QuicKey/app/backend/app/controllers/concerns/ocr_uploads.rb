require "image_processing/vips"

# OCR 上傳檔案的共用處理：/api/ocr/recognize（OcrController）與 /api/ocr/batch（OcrBatchesController）。
module OcrUploads
  extend ActiveSupport::Concern

  ALLOWED_MIMES = %w[image/jpeg image/png image/webp image/heic application/pdf].freeze
  HEIC_MIMES    = %w[image/heic image/heif].freeze

  private

  def uploaded_files
    Array(params[:files]).select { |f| f.is_a?(ActionDispatch::Http::UploadedFile) }
  end

  # 只看檔案內容判斷格式，不採信副檔名與瀏覽器送來的 Content-Type（避免改副檔名繞過）。
  def detect_mime(file)
    mime = Marcel::MimeType.for(Pathname(file.tempfile.path))
    HEIC_MIMES.include?(mime) ? "image/heic" : mime
  end

  # to_jpeg 列出的圖片格式轉成 JPEG（預設只轉 HEIC：Gemini 不收 iPhone 預設格式）。
  # 轉檔前先看檔頭的寬 × 高，超過像素上限就當作檔案無法辨識（不送 Google、不扣次）。
  def document_payload(file, mime, to_jpeg: %w[image/heic])
    return [ File.binread(file.tempfile.path), mime ] unless to_jpeg.include?(mime)

    image = Vips::Image.new_from_file(file.tempfile.path)
    if image.width * image.height > Ocr::QrScanner::MAX_PIXELS
      raise Ocr::GeminiClient::InvalidDocument, "image too large"
    end
    jpeg = ImageProcessing::Vips.source(image).convert("jpg").call
    [ File.binread(jpeg.path), "image/jpeg" ]
  end

  def render_error(status, code, message, quota: nil, required: nil)
    render json: { code: code, message: message, quota: quota, required: required }.compact, status: status
  end
end
