module Ocr
  # 批次匯入憑證（docs/OCR辨識規格.md §9、docs/資料模型.md §5.5）分兩步，各自最多 THREADS 件同時處理、
  # 各有期限 TIME_LIMIT 秒（正式環境前面的 Cloudflare 約 100 秒就斷線）：
  # - locate：上傳時每頁送 Gemini 一次，只找出每張憑證的框（[ymin, xmin, ymax, xmax]，0–1000），不辨識內容。
  # - recognize：確認後把所選頁轉成圖（PDF 用 pdftoppm），每個框四周多留一點邊裁成單張 JPEG，
  #   逐張用單張的 prompt 辨識；每張各自解 QR，照 §3.2 套用（QR 優先）。
  #   整頁一次辨識多張時每張的解析度不夠，發票號碼、金額常讀不到，所以裁成單張再辨識。
  #
  # 期限到了還沒做完的頁或憑證當作逾時。任一件遇到 GeminiClient::Unavailable：其他件不再送出、
  # 進行中的直接中止，整批往外丟（回 503）。
  class BatchRecognizer
    class Unreadable < StandardError; end

    THREADS      = 10
    MAX_PER_PAGE = 10
    TIME_LIMIT   = 90
    # 框四周多留的邊（千分比，以整頁為準），框得太緊時不會切掉憑證邊緣
    MARGIN       = 30
    # 框的寬或高小於這個值（千分比）不算一張憑證
    MIN_BOX      = 10
    # PDF 轉圖、裁好的圖長邊上限（A4 約 300 dpi）
    MAX_EDGE     = 3600
    JPEG_QUALITY = 90
    # PDF 轉圖最多等幾秒（同時也不超過整批期限）
    RENDER_TIMEOUT = 30

    Page = Data.define(:id, :file_index, :filename, :number, :bytes, :mime)
    # boxes：找到的框；truncated：超過每頁上限被捨棄；invalid：Google 回 400；timed_out：期限到了還沒找完
    Located = Data.define(:page, :boxes, :truncated, :invalid, :timed_out) do
      def self.empty(page, invalid: false, timed_out: false)
        new(page: page, boxes: [], truncated: false, invalid: invalid, timed_out: timed_out)
      end
    end
    # 每張憑證的辨識結果。status：
    # - :recognized：辨識出內容，result 為 ResultMerger 的結果（結構同 /api/ocr/recognize，不含 quota）
    # - :empty：辨識不出內容；:invalid：Google 回 400 或這頁轉不成圖；:timed_out：期限到了還沒辨識完
    Receipt = Data.define(:status, :result)

    def self.locate(pages, client:)
      new(client: client).locate(pages)
    end

    # selections：[ [Page, boxes], ... ]；回傳每頁一個 Receipt 陣列（順序同 boxes）。
    def self.recognize(selections, client:, role:)
      new(client: client, role: role).recognize(selections)
    end

    # [ymin, xmin, ymax, xmax]：夾在 0–1000、上下或左右顛倒時對調；格式不對或太小的框回 nil。
    def self.normalize_box(box)
      return nil unless box.is_a?(Array) && box.size == 4 && box.all? { |v| v.is_a?(Numeric) && v.finite? }
      ymin, xmin, ymax, xmax = box.map { |v| v.round.clamp(0, 1000) }
      ymin, ymax = [ ymin, ymax ].minmax
      xmin, xmax = [ xmin, xmax ].minmax
      return nil if ymax - ymin < MIN_BOX || xmax - xmin < MIN_BOX
      [ ymin, xmin, ymax, xmax ]
    end

    # 框四周加上 MARGIN 換算成像素，夾在圖內：[left, top, width, height]，寬高至少 1 像素。
    def self.crop_region(box, width, height)
      ymin, xmin, ymax, xmax = box
      left, right = pixel_range(xmin, xmax, width)
      top, bottom = pixel_range(ymin, ymax, height)
      [ left, top, right - left, bottom - top ]
    end

    def self.pixel_range(from, to, size)
      start  = ((from - MARGIN).clamp(0, 1000) * size / 1000.0).floor.clamp(0, size - 1)
      finish = ((to + MARGIN).clamp(0, 1000) * size / 1000.0).ceil.clamp(start + 1, size)
      [ start, finish ]
    end
    private_class_method :pixel_range

    def initialize(client:, role: nil)
      @client = client
      @role   = role
    end

    # 回傳 Located 陣列，順序同 pages。
    def locate(pages)
      deadline = now + TIME_LIMIT
      results = parallel(pages, deadline) { |page| locate_page(page) }
      pages.each_with_index.map { |page, i| results[i] || Located.empty(page, timed_out: true) }
    end

    # 先把每頁轉成圖、裁好每張，再逐張辨識；兩段共用同一個期限。
    def recognize(selections)
      @deadline = now + TIME_LIMIT
      crops = parallel(selections, @deadline) do |page, boxes|
        crop_page(page, boxes)
      rescue Unreadable, PdfPages::Unreadable, Vips::Error => e
        Rails.logger.warn("[ocr] batch page #{page.id} crop failed: #{e.class}: #{e.message}")
        :invalid
      end

      jobs = selections.each_with_index.flat_map do |(page, _), i|
        crops[i].is_a?(Array) ? crops[i].each_with_index.map { |bytes, n| [ i, n, page, bytes ] } : []
      end
      recognized = parallel(jobs, @deadline) { |_, _, page, bytes| recognize_crop(page, bytes) }
      by_box = jobs.each_with_index.to_h { |(i, n, _, _), j| [ [ i, n ], recognized[j] ] }

      selections.each_with_index.map do |(_, boxes), i|
        boxes.each_index.map do |n|
          case crops[i]
          when nil      then Receipt.new(status: :timed_out, result: nil)
          when :invalid then Receipt.new(status: :invalid, result: nil)
          else by_box[[ i, n ]] || Receipt.new(status: :timed_out, result: nil)
          end
        end
      end
    end

    private

    # items 逐件交給 block，最多 THREADS 件同時處理，做到 deadline 為止；回傳結果陣列（順序同 items，
    # 期限到了還沒做完的為 nil）。任一件丟錯：其他件不再開始、進行中的中止，把錯往外丟。
    def parallel(items, deadline)
      return [] if items.empty?

      jobs = Queue.new
      items.each_with_index { |item, i| jobs << [ item, i ] }
      jobs.close
      results = Array.new(items.size)
      error = nil
      stopped = false
      lock = Mutex.new

      threads = Array.new([ THREADS, items.size ].min) do
        Thread.new do
          Rails.application.executor.wrap do
            while (job = jobs.pop)
              break if lock.synchronize { stopped || error }
              item, i = job
              result = yield(item)
              lock.synchronize { results[i] = result unless stopped }
            end
          end
        rescue StandardError => e
          lock.synchronize { error ||= e }
        end
      end

      # 等到全部做完、有一件出錯或期限到；開發環境自動載入程式時，子執行緒要能取得載入鎖，等待期間先讓出
      ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
        sleep 0.05 until threads.none?(&:alive?) || lock.synchronize { error } || now >= deadline
      end
      lock.synchronize { stopped = true }
      # 還在等 Google 的直接中止（Net::HTTP、pdftoppm、QR 的子行程都會在 ensure 收尾）
      threads.each { |t| t.kill.join }
      raise error if error

      results
    end

    def locate_page(page)
      bytes, mime = locate_payload(page)
      boxes = boxes_from(@client.locate_receipts(bytes, mime).data)
      Located.new(page: page, boxes: boxes.first(MAX_PER_PAGE), truncated: boxes.size > MAX_PER_PAGE,
                  invalid: false, timed_out: false)
    rescue GeminiClient::InvalidDocument => e
      Rails.logger.warn("[ocr] batch page #{page.id} rejected: #{e.message}")
      Located.empty(page, invalid: true)
    end

    # 照片有旋轉標記時先轉正再找位置，確認時裁切用的圖（也轉正）座標才對得上。PDF、沒有旋轉的圖片照原檔送。
    def locate_payload(page)
      return [ page.bytes, page.mime ] if page.mime == "application/pdf"
      image = Vips::Image.new_from_buffer(page.bytes, "")
      return [ page.bytes, page.mime ] unless rotated?(image)
      [ image.autorot.jpegsave_buffer(Q: JPEG_QUALITY), "image/jpeg" ]
    rescue Vips::Error
      [ page.bytes, page.mime ]
    end

    def rotated?(image)
      image.get_typeof("orientation").positive? && image.get("orientation") > 1
    end

    # 回應被截斷、被安全機制擋下或格式不對時當作這頁沒有憑證。
    def boxes_from(data)
      list = data.is_a?(Hash) ? data["receipts"] : nil
      return [] unless list.is_a?(Array)
      list.filter_map { |r| self.class.normalize_box(r["box_2d"]) if r.is_a?(Hash) }
    end

    # 每個框裁成一張 JPEG（長邊超過 MAX_EDGE 先縮小）。
    def crop_page(page, boxes)
      image = page_image(page)
      boxes.map do |box|
        left, top, width, height = self.class.crop_region(box, image.width, image.height)
        crop = image.crop(left, top, width, height)
        scale = MAX_EDGE.to_f / [ width, height ].max
        crop = crop.resize(scale) if scale < 1
        crop.jpegsave_buffer(Q: JPEG_QUALITY)
      end
    end

    # PDF 用 pdftoppm 轉成彩色圖；圖片照旋轉標記轉正。透明背景補白、統一成 sRGB（JPEG 只收這種）。
    def page_image(page)
      image =
        if page.mime == "application/pdf"
          timeout = [ [ @deadline - now, RENDER_TIMEOUT ].min, 1 ].max
          Vips::Image.new_from_buffer(PdfPages.to_jpeg(page.bytes, max_edge: MAX_EDGE, timeout: timeout), "")
        else
          image = Vips::Image.new_from_buffer(page.bytes, "")
          raise Unreadable, "image too large" if image.width * image.height > QrScanner::MAX_PIXELS
          image.autorot
        end
      image = image.flatten(background: 255) if image.has_alpha?
      image.colourspace(:srgb)
    end

    def recognize_crop(page, bytes)
      invoices = scan_invoices(page, bytes)
      response = @client.recognize(bytes, "image/jpeg")
      extracted = extract_fields(page, response.data)
      result = InvoiceQr.apply(extracted, invoices, role: @role, source_index: 0, names: party_names(response.data))
      return Receipt.new(status: :empty, result: nil) unless ResultMerger.recognized?(result)
      Receipt.new(status: :recognized, result: ResultMerger.call([ result ]))
    rescue GeminiClient::InvalidDocument => e
      Rails.logger.warn("[ocr] batch page #{page.id} receipt rejected: #{e.message}")
      Receipt.new(status: :invalid, result: nil)
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # 以下三個的錯誤處理同 OcrController：出任何錯都當作沒有結果；log 不記內容與統編。
    def extract_fields(page, data)
      ReceiptExtractor.call(data, role: @role, source_index: 0)
    rescue StandardError => e
      Rails.logger.error("[ocr] batch page #{page.id} extract failed: #{e.class}: #{e.message}")
      nil
    end

    def party_names(data)
      ReceiptExtractor.new(data, role: @role, source_index: nil).party_names
    rescue StandardError
      {}
    end

    def scan_invoices(page, bytes)
      InvoiceQr.call(QrScanner.call(bytes, "image/jpeg"))
    rescue StandardError => e
      Rails.logger.info("[ocr] batch page #{page.id} qr parse failed: #{e.class}: #{e.message}")
      []
    end
  end
end
