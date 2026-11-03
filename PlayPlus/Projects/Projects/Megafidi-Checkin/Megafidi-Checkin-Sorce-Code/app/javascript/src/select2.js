import select2 from 'select2';
select2();

document.addEventListener("DOMContentLoaded", function() {
  
	$( ".js-select2" ).select2({
    theme: 'bootstrap4',
  	width: '100%'
	});

  $(".js-select2-tag").select2({
    placeholder: "輸入tag",
    allowClear: false,
    theme: 'bootstrap4',
		width: '100%',
    tags: true,
    tokenSeparators: [','],
    createTag: function(params) {
      if (params.term.indexOf('，') > 0 || params.term.indexOf(',') > 0) {
        var str = params.term;
        str = str.substr(0, str.length - 1);
        return {
          id: str,
          text: str
        }
      } else {
        return null;
      }
    }
  });

});