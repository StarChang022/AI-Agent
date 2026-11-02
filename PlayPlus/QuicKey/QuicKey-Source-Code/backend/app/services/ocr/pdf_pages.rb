require "tmpdir"

module Ocr
  # PDF 頁數（OCR 按頁計次用）、拆單頁（批次匯入每張憑證附上所在頁用）與轉圖（批次匯入裁切每張憑證用）。
  # Gemini 不回頁數，改用 poppler 的 pdfinfo 讀；拆頁用 pdfseparate；轉圖用 pdftoppm。
  #
  # 這些程式解析的都是使用者上傳的 PDF：不繼承 Rails 的環境變數（資料庫密碼、Google 金鑰），並限制記憶體與時間。
  class PdfPages
    class Unreadable < StandardError; end

    PDFINFO     = "pdfinfo".freeze
    PDFSEPARATE = "pdfseparate".freeze
    PDFTOPPM    = "pdftoppm".freeze
    TIMEOUT       = 10
    SPLIT_TIMEOUT = 30
    MEMORY  = 1024**3
    # 超過這個頁數不送 Google（跟 QrScanner 只解前 10 頁不同：這裡是辨識成本的上限）
    MAX_PAGES = 15

    # 回傳頁數；讀不出來（檔案壞掉、加密）raise Unreadable；pdfinfo 沒安裝 raise GeminiClient::Unavailable
    # （頁數關係到扣次與成本，不默默當 1 頁）。
    def self.count(bytes)
      Tempfile.create([ "ocr", ".pdf" ], binmode: true) do |file|
        file.write(bytes)
        file.flush
        output = capture([ PDFINFO, file.path ], timeout: TIMEOUT)
        pages = output[/^Pages:\s+(\d+)/, 1].to_i
        raise Unreadable, "no pages" unless pages.positive?
        pages
      end
    end

    # 拆成單頁 PDF，依頁序回傳每頁的內容。錯誤處理同 count。
    def self.split(bytes)
      Dir.mktmpdir("ocr-split") do |dir|
        source = File.join(dir, "source.pdf")
        File.binwrite(source, bytes)
        capture([ PDFSEPARATE, source, File.join(dir, "page-%d.pdf") ], timeout: SPLIT_TIMEOUT)

        paths = Dir[File.join(dir, "page-*.pdf")].sort_by { |path| path[/(\d+)\.pdf\z/, 1].to_i }
        raise Unreadable, "no pages" if paths.empty?
        paths.map { |path| File.binread(path) }
      end
    end

    # 第一頁轉成彩色 JPEG（長邊 max_edge 像素；印章多半是藍色，不轉灰階），回傳內容。錯誤處理同 count。
    # 輸出 JPEG 而不是 PPM：Rails 封鎖 libvips 讀 PPM / PGM，JPEG 可以直接交給 libvips 裁切。
    def self.to_jpeg(bytes, max_edge:, timeout:)
      Dir.mktmpdir("ocr-render") do |dir|
        source = File.join(dir, "source.pdf")
        output = File.join(dir, "page")
        File.binwrite(source, bytes)
        capture([ PDFTOPPM, "-jpeg", "-jpegopt", "quality=95", "-scale-to", max_edge.to_s,
                  "-f", "1", "-l", "1", "-singlefile", source, output ], timeout: timeout)

        path = "#{output}.jpg"
        raise Unreadable, "no image" unless File.exist?(path)
        File.binread(path)
      end
    end

    # 參數用陣列傳入，不經 shell；回傳標準輸出。
    def self.capture(command, timeout:)
      options = { unsetenv_others: true, in: File::NULL, err: File::NULL }
      options[:rlimit_as] = MEMORY if RUBY_PLATFORM.include?("linux")
      reader, writer = IO.pipe
      pid = Process.spawn({ "PATH" => ENV["PATH"] }, *command, **options, out: writer)
      writer.close
      output = Timeout.timeout(timeout) { reader.read }
      _, status = Process.wait2(pid)
      pid = nil
      raise Unreadable, "#{command.first} failed" unless status.success?
      output
    rescue Errno::ENOENT
      raise GeminiClient::Unavailable, "#{command.first} not available"
    rescue Timeout::Error
      raise Unreadable, "#{command.first} timed out"
    ensure
      reader&.close
      writer&.close
      if pid
        Process.kill("KILL", pid) rescue nil
        Process.wait(pid) rescue nil
      end
    end
    private_class_method :capture
  end
end
