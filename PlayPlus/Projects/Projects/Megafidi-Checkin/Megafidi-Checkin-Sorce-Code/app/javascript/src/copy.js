document.addEventListener("DOMContentLoaded", function() {
  $(".js-copy").on('click',function(){
    let item = document.createElement('input'),
    text = $(this).data("copy");

    document.body.appendChild(item);
    item.value = text;
    item.select();
    document.execCommand('copy');
    document.body.removeChild(item);

    new Noty({
      type: "success",
      text: "複製成功"
    }).show();

  })
});    