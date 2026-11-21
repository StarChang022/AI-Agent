require "ffi"
require "tmpdir"

module Ocr
  # 解出圖片 / PDF 每一頁裡所有 QR Code 的原始內容。見 docs/OCR辨識規格.md §3.2。
  #
  # 回傳：[ { data: "原始位元組（ASCII-8BIT）", page: 0, x: 120, y: 340, height: 180 }, ... ]
  #       依頁序、再由上到下、由左到右排序（x / y 是 QR 左上角、height 是 QR 高度，單位為縮圖後的像素）。
  #       y 差距在 QR 高度一半以內的算同一列，同一列由左到右（左右並排的發票不會因為差 1px 而排反）。
  #
  # - 圖片用 libvips 讀、轉灰階；PDF 交給另一個程式 pdftoppm（poppler-utils）把每頁長邊轉成 3600px 的灰階圖。
  #   Rails 預設封鎖 libvips 讀 PDF / PGM（沒做過安全模糊測試），使用者上傳的 PDF 不在 Rails 程式內解析，
  #   轉出來的 PGM 也由這裡自己讀表頭與像素，不經 libvips 的讀檔器。
  # - 灰階像素交給 zbar C 函式庫（libzbar）解碼。
  # - zbar 設成不轉換字元，拿到原始位元組；中文是 Big5 還是 UTF-8 由 InvoiceQr 依 QR 裡的編碼參數決定。
  # - QR 只是加分項：找不到 libzbar、讀圖失敗、超過時限都回已解出的部分（或 []），不往外丟錯。
  # - 時限：pdftoppm 超過總時限就直接終止、當作沒有 QR；zbar 解碼時 Ruby 無法中途打斷，
  #   所以用「先縮圖 + 每頁開始前檢查總時限」控制。
  class QrScanner
    # 長邊超過這個像素先縮小，限制每頁解碼時間；PDF 每頁也直接轉成這個長邊（A4 約 307 dpi）
    MAX_EDGE    = 3600
    # 圖片像素上限（1 億）：先看檔頭的寬 × 高，超過就不讀（壓縮率高的小檔也可能是超大圖）。
    # 手機 4800 萬畫素照片約 4800 萬像素。controller 轉 HEIC 時也用這個上限。
    MAX_PIXELS  = 100_000_000
    # 每個檔案的總時限（秒），PDF 轉圖也算在內；超過就不再解剩下的頁
    TIME_LIMIT  = 3.0
    # PDF 只轉前幾頁（一般一份 PDF 不會掃超過 10 張電子發票）
    MAX_PDF_PAGES = 10
    # 讀 PGM 時的單頁像素上限；-scale-to 之後最多 3600 × 3600，這裡只是保險
    MAX_PDF_PIXELS = 35_000_000
    PDFTOPPM    = "pdftoppm"
    # pdftoppm 可用的記憶體上限（位元組）；正常一頁只要幾十 MB
    PDFTOPPM_MEMORY = 1024**3
    PGM_HEADER  = /\AP5\s+(\d+)\s+(\d+)\s+255\s/n
    ZBAR_LIBS   = %w[zbar libzbar.so.0].freeze
    ZBAR_QRCODE = 64
    ZBAR_CFG_ENABLE = 0
    ZBAR_CFG_BINARY = 4
    Y800 = "Y800".unpack1("V")

    def self.call(bytes, mime)
      new(bytes, mime).call
    end

    # libzbar 只在第一次用到時載入；找不到時記一次 log，之後一律當作沒有 QR（不影響開機與辨識）。
    def self.zbar
      return @zbar if defined?(@zbar)
      @zbar = Module.new do
        extend FFI::Library
        ffi_lib ZBAR_LIBS
        attach_function :zbar_image_scanner_create, [], :pointer
        attach_function :zbar_image_scanner_destroy, [ :pointer ], :void
        attach_function :zbar_image_scanner_set_config, [ :pointer, :int, :int, :int ], :int
        attach_function :zbar_image_create, [], :pointer
        attach_function :zbar_image_destroy, [ :pointer ], :void
        attach_function :zbar_image_set_format, [ :pointer, :ulong ], :void
        attach_function :zbar_image_set_size, [ :pointer, :uint, :uint ], :void
        attach_function :zbar_image_set_data, [ :pointer, :pointer, :ulong, :pointer ], :void
        attach_function :zbar_scan_image, [ :pointer, :pointer ], :int, blocking: true
        attach_function :zbar_image_first_symbol, [ :pointer ], :pointer
        attach_function :zbar_symbol_next, [ :pointer ], :pointer
        attach_function :zbar_symbol_get_type, [ :pointer ], :int
        attach_function :zbar_symbol_get_data, [ :pointer ], :pointer
        attach_function :zbar_symbol_get_data_length, [ :pointer ], :uint
        attach_function :zbar_symbol_get_loc_size, [ :pointer ], :uint
        attach_function :zbar_symbol_get_loc_x, [ :pointer, :uint ], :int
        attach_function :zbar_symbol_get_loc_y, [ :pointer, :uint ], :int
      end
    rescue LoadError, FFI::NotFoundError => e
      Rails.logger.warn("[ocr] libzbar not available, QR decoding disabled: #{e.message}")
      @zbar = nil
    end

    # 找不到 pdftoppm、zbar 不支援原始位元組模式時，各只記一次 log
    def self.warn_once(key, message)
      @warned ||= {}
      return if @warned[key]
      @warned[key] = true
      Rails.logger.warn(message)
    end

    def initialize(bytes, mime)
      @bytes = bytes
      @pdf   = mime == "application/pdf"
    end

    def call
      zbar = self.class.zbar
      return [] unless zbar

      @deadline = now + TIME_LIMIT
      codes = []
      each_page do |page, image|
        break if now > @deadline
        codes.concat(scan(zbar, image).map { |code| code.merge(page: page) })
      end
      reading_order(codes)
    rescue StandardError => e
      # log 只記錯誤類別與訊息，不記 QR 內容
      Rails.logger.info("[ocr] qr scan failed: #{e.class}: #{e.message}")
      codes || []
    end

    private

    def reading_order(codes)
      codes.group_by { |c| c[:page] }.sort.flat_map do |_, page_codes|
        rows = []
        page_codes.sort_by { |c| c[:y] }.each do |code|
          row = rows.last
          if row && code[:y] - row.first[:y] <= row.first[:height] / 2.0
            row << code
          else
            rows << [ code ]
          end
        end
        rows.flat_map { |row| row.sort_by { |c| c[:x] } }
      end
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def each_page
      unless @pdf
        # new_from_buffer 只先讀檔頭，寬高不用解整張圖；超過像素上限就不讀
        image = Vips::Image.new_from_buffer(@bytes, "")
        return if image.width * image.height > MAX_PIXELS
        return yield(0, grayscale(image))
      end

      Dir.mktmpdir("ocr-qr") do |dir|
        pdf_path = File.join(dir, "source.pdf")
        File.binwrite(pdf_path, @bytes)
        next unless pdftoppm(pdf_path, File.join(dir, "page"))

        # 輸出檔名是 page-1.pgm、page-01.pgm 這類（位數依總頁數），照頁碼數字排序
        Dir[File.join(dir, "page-*.pgm")].sort_by { |path| path[/(\d+)\.pgm\z/, 1].to_i }.each_with_index do |path, page|
          image = read_pgm(path)
          yield(page, grayscale(image)) if image
        end
      end
    end

    # 參數用陣列傳入，不經 shell；超過總時限就終止 pdftoppm，當作沒有 QR。
    # pdftoppm 解析的是使用者上傳的 PDF：不繼承 Rails 的環境變數（資料庫密碼、Google 金鑰），並限制記憶體。
    def pdftoppm(pdf_path, output_root)
      command = [ PDFTOPPM, "-scale-to", MAX_EDGE.to_s, "-gray", "-f", "1", "-l", MAX_PDF_PAGES.to_s, pdf_path, output_root ]
      options = { unsetenv_others: true, in: File::NULL, out: File::NULL, err: File::NULL }
      # 記憶體上限只在 Linux（正式環境）設定；macOS 不支援這個上限，設了會無法執行
      options[:rlimit_as] = PDFTOPPM_MEMORY if RUBY_PLATFORM.include?("linux")
      pid = Process.spawn({ "PATH" => ENV["PATH"] }, *command, **options)
      loop do
        _, status = Process.wait2(pid, Process::WNOHANG)
        if status
          pid = nil
          return status.success?
        end
        if now > @deadline
          Rails.logger.info("[ocr] pdftoppm timed out")
          return false
        end
        sleep 0.02
      end
    rescue Errno::ENOENT => e
      self.class.warn_once(:pdftoppm, "[ocr] pdftoppm not available, PDF QR decoding disabled: #{e.message}")
      false
    ensure
      # 超時、或這條 thread 被中斷時，pdftoppm 還沒結束就直接終止並收回，不留在背景
      if pid
        begin
          Process.kill("KILL", pid)
          Process.wait(pid)
        rescue Errno::ESRCH, Errno::ECHILD
          nil
        end
      end
    end

    # pdftoppm -gray 輸出的 PGM：「P5 寬 高 255」表頭 + 每像素 1 位元組
    def read_pgm(path)
      header = File.binread(path, 64)
      match = header&.match(PGM_HEADER)
      return nil unless match
      width, height = match[1].to_i, match[2].to_i
      return nil if width.zero? || height.zero? || width * height > MAX_PDF_PIXELS

      pixels = File.binread(path, width * height, match.end(0))
      return nil unless pixels && pixels.bytesize == width * height
      Vips::Image.new_from_memory_copy(pixels, width, height, 1, :uchar)
    end

    def grayscale(image)
      scale = MAX_EDGE.to_f / [ image.width, image.height ].max
      image = image.resize(scale) if scale < 1
      image = image.flatten(background: 255) if image.has_alpha?
      image.colourspace(:b_w).extract_band(0).cast(:uchar)
    end

    def scan(zbar, image)
      pixels  = image.write_to_memory
      buffer  = FFI::MemoryPointer.from_string(pixels)
      scanner = zbar.zbar_image_scanner_create
      zimage  = zbar.zbar_image_create
      return [] if scanner.null? || zimage.null?

      zbar.zbar_image_scanner_set_config(scanner, 0, ZBAR_CFG_ENABLE, 0)
      zbar.zbar_image_scanner_set_config(scanner, ZBAR_QRCODE, ZBAR_CFG_ENABLE, 1)
      # 舊版 zbar（0.10）沒有這個設定，Big5 品名會被轉壞；記一次 log 方便查
      unless zbar.zbar_image_scanner_set_config(scanner, ZBAR_QRCODE, ZBAR_CFG_BINARY, 1).zero?
        self.class.warn_once(:zbar_binary, "[ocr] libzbar does not support binary mode; QR text may be mis-decoded")
      end
      zbar.zbar_image_set_format(zimage, Y800)
      zbar.zbar_image_set_size(zimage, image.width, image.height)
      zbar.zbar_image_set_data(zimage, buffer, pixels.bytesize, nil)
      return [] unless zbar.zbar_scan_image(scanner, zimage).positive?

      codes = []
      symbol = zbar.zbar_image_first_symbol(zimage)
      until symbol.null?
        if zbar.zbar_symbol_get_type(symbol) == ZBAR_QRCODE
          data = zbar.zbar_symbol_get_data(symbol).read_bytes(zbar.zbar_symbol_get_data_length(symbol))
          points = Array.new(zbar.zbar_symbol_get_loc_size(symbol)) do |i|
            [ zbar.zbar_symbol_get_loc_x(symbol, i), zbar.zbar_symbol_get_loc_y(symbol, i) ]
          end
          ys = points.map(&:last)
          codes << { data: data, x: points.map(&:first).min.to_i, y: ys.min.to_i, height: ys.max.to_i - ys.min.to_i }
        end
        symbol = zbar.zbar_symbol_next(symbol)
      end
      codes
    ensure
      zbar.zbar_image_destroy(zimage) if zimage && !zimage.null?
      zbar.zbar_image_scanner_destroy(scanner) if scanner && !scanner.null?
      # zbar 掃描期間要用到 buffer，這裡明確留著，避免日後重構讓它提早被回收
      buffer&.free
    end
  end
end
