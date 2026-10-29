# 示範：QrScanner 擋超大 PDF 頁面 / 超大像素圖，以及 InvoiceQr 品項區出錯不丟掉表頭。
# 只是示範寫法，沒有改 app/。2026-10-28 後端審查，對應 docs/reviews/後端審查-2026-10-28.md 的 M-1、M-2、M-3 與第二版建議。
#
# 實測（libvips 8.16.1 + poppler，本機）：
#   390KB 的 PNG（20000×20000）：現行寫法讀圖+縮圖 2.2 秒；下面的寫法在讀檔頭時就略過，幾乎 0 秒。
#   MediaBox 14400pt 的 PDF：pdftoppm -scale-to 3600 得到 3600×3600、13MB。

module Ocr
  class QrScanner
    MAX_PIXELS = 100_000_000 # 1 億像素；A4 300 dpi 約 870 萬、手機 4800 萬畫素照片約 4800 萬

    # --- M-1：圖片先看像素數再讀（加在 each_page 的圖片分支）---
    # new_from_buffer 是延遲讀取，這時只讀了檔頭，width / height 幾乎不花時間。
    def checked_image
      image = Vips::Image.new_from_buffer(@bytes, "")
      image.width * image.height > MAX_PIXELS ? nil : image
    end

    # --- M-3：pdftoppm 用 -scale-to 取代 -r（第二版）---
    # 實測 MediaBox 14400pt 的頁面：-r 300 會先渲染（3600pt 頁面 2.4 秒 / 450MB RSS / 225MB 磁碟），
    # -scale-to 3600 得到 3600×3600、13MB 的 PGM。
    def pdftoppm_command(pdf_path, output_root)
      [ PDFTOPPM, "-scale-to", MAX_EDGE.to_s, "-gray", "-f", "1", "-l", MAX_PDF_PAGES.to_s, pdf_path, output_root ]
    end

    # --- 第二版：spawn 後即使被中斷也不留孤兒；子程序不繼承 Rails 的環境變數 ---
    def run_pdftoppm(command)
      pid = Process.spawn({ "PATH" => ENV["PATH"] }, *command, unsetenv_others: true,
                          in: File::NULL, out: File::NULL, err: File::NULL, rlimit_as: 2 * 1024**3)
      # ……原本的 wait2(WNOHANG) 迴圈……
    ensure
      if pid && !Process.wait2(pid, Process::WNOHANG)
        Process.kill("KILL", pid)
        Process.wait(pid)
      end
    end
  end

  class InvoiceQr
    # --- 取代現行 text ---
    # 現行寫法：Big5 裡「編碼合法但沒有 Unicode 對應」的雙位元組（例如 A3C0）會丟
    # Encoding::UndefinedConversionError，整個檔案的發票（號碼、日期、金額）都被 controller 的 rescue 丟掉。
    # 只要品名裡有一個這種字就中。Ruby 的 Big5 有 847 個這種組合；改用 CP950 降到 62 個。
    def text(bytes, encoding)
      value = bytes.to_s.dup.force_encoding(encoding)
      return nil unless value.valid_encoding?
      ReceiptTextExtractor.normalize_text(value.encode(Encoding::UTF_8, undef: :replace, replace: "").gsub("　", " "))
    end

    # --- 取代現行 call 裡 items(...) 的呼叫 ---
    # 品項是加分項：品項區任何錯（編碼、超長數字 → FloatDomainError）都只讓 items 變 []，不影響表頭欄位。
    def safe_items(left, right)
      items(left, right)
    rescue StandardError
      []
    end
  end
end
