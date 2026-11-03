document.addEventListener("DOMContentLoaded", function() {
  var sortItems = $(".sortable_items");

  let authenticity_token = document.querySelector("meta[name='csrf-token']").getAttribute("content");

  sortItems.each(function(){
    $(this).sortable({
      handle: ".handle",
      cancel: '',
      stop : function(event, ui) {

        let collection = $(this).children();
        let url = ui.item.data("acts_as_list_url")

        if (url == undefined){
          collection.each(function(index) {
            $(this).find("._priority").val(index+1)
          });          
        }else{

         let priority
          if( ui.item.prev().length > 0 ){
            priority = ui.item.prev().data("obj")['priority']
          }
          if( ui.item.next().length > 0 ){
            priority = ui.item.next().data("obj")['priority']
          }
          let bulk_ids = [];
          collection.each(function(){
            bulk_ids.push($(this).data('obj')['id'])
          })
          let payload = {
            authenticity_token: authenticity_token,
            bulk_ids: bulk_ids,
            id: ui.item.data("obj")['id'],
            priority: priority,
          }

          $.ajax({
            url : url,
            type : 'post',
            data : payload,
            error : function(XMLHttpRequest, textStatus, errorThrown) {

            },
            success : function(response) {
              collection.each(function(index) {
                $(this).data('obj', response.collection.find(i => i.id == $(this).data('obj')['id'] ))
              });    
            },
          });          
        }

      },
    });
  })

});