import tinymce from 'tinymce/tinymce'
import 'tinymce/models/dom/model'
import 'tinymce/themes/silver/theme'
import 'tinymce/icons/default/icons'

import './tinymce/zh-Hant.js'

import 'tinymce/plugins/preview/plugin'
import 'tinymce/plugins/importcss/plugin'
import 'tinymce/plugins/searchreplace/plugin'
import 'tinymce/plugins/autolink/plugin'
import 'tinymce/plugins/autosave/plugin'
import 'tinymce/plugins/save/plugin'
import 'tinymce/plugins/directionality/plugin'
import 'tinymce/plugins/code/plugin'
import 'tinymce/plugins/visualblocks/plugin'
import 'tinymce/plugins/visualchars/plugin'
import 'tinymce/plugins/fullscreen/plugin'
import 'tinymce/plugins/image/plugin'
import 'tinymce/plugins/link/plugin'
import 'tinymce/plugins/media/plugin'
import 'tinymce/plugins/codesample/plugin'
import 'tinymce/plugins/table/plugin'
import 'tinymce/plugins/charmap/plugin'
import 'tinymce/plugins/pagebreak/plugin'
import 'tinymce/plugins/nonbreaking/plugin'
import 'tinymce/plugins/anchor/plugin'
import 'tinymce/plugins/insertdatetime/plugin'
import 'tinymce/plugins/advlist/plugin'
import 'tinymce/plugins/lists/plugin'
import 'tinymce/plugins/wordcount/plugin'
import 'tinymce/plugins/help/plugin'
import 'tinymce/plugins/charmap/plugin'
import 'tinymce/plugins/quickbars/plugin'
import 'tinymce/plugins/emoticons/plugin'
import 'tinymce/plugins/emoticons/js/emojis'

document.addEventListener("DOMContentLoaded", function() {

  tinymce.init({
    selector: '.p-tinymce',
    language: 'zh-Hant',
    toolbar: 'undo redo | bold italic underline strikethrough | fontfamily fontsize blocks | alignleft aligncenter alignright alignjustify | outdent indent |  numlist bullist | forecolor backcolor removeformat | pagebreak | charmap emoticons | fullscreen  preview save print | insertfile image media template link anchor codesample',
    plugins: "preview importcss searchreplace autolink autosave save directionality code visualblocks visualchars fullscreen image link media codesample table charmap pagebreak nonbreaking anchor insertdatetime advlist lists wordcount help charmap quickbars emoticons",  
    template_cdate_format: '[Date Created (CDATE): %m/%d/%Y : %H:%M:%S]',
    template_mdate_format: '[Date Modified (MDATE): %m/%d/%Y : %H:%M:%S]',
    height: 400,
    quickbars_selection_toolbar: 'bold italic forecolor backcolor quicklink fontsize h2 h3 blockquote quickimage quicktable',
    noneditable_class: 'mceNonEditable',
    toolbar_mode: 'sliding',
    contextmenu: 'link image table',
    skin: 'oxide',
    content_css:'default',
    relative_urls : false,
    remove_script_host : true,
    content_style: 'body { font-family:微軟正黑體,Helvetica,Arial,sans-serif; font-size:16px }',
    image_caption: true,
    image_dimensions: false,
    images_upload_url: '/content_images/tinymce',
    base_url: '/tinymce',
  });

});