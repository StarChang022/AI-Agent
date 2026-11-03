import dropify from 'dropify'

document.addEventListener("DOMContentLoaded", function() {

  $('.js-dropify').dropify({
    messages: {
      'default': '點擊或將檔案拖放到此處',
      'replace': '點擊或將檔案拖放到此處',
      'remove':  '移除',
      'error':   'Ooops, 發生了一點錯誤'
    }
  });

});