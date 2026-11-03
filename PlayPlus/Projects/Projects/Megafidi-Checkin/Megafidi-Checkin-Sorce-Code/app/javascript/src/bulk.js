// togggle
document.addEventListener("DOMContentLoaded", function () {
  $(document).on("click", "input.toggle", function () {
    $("[name='bulk_ids[]']").attr("checked", $(this).is(":checked"));
  });

  $(document).on("click", "[data-bulk_action]", function () {
    if (
      $(this).data("v_confirm") == undefined ||
      confirm(`${$(this).data("v_confirm")}`)
    ) {
      if ($("[name='bulk_ids[]']:checked").length == 0) {
        alert("請先選擇資料。");
        return;
      }

      $("#bulk_form #bulk_action").val($(this).data("bulk_action"));
      $("#bulk_form #bulk_event").val($(this).data("bulk_event"));

      $("#bulk_form .bulk_ids").html("");
      $("[name='bulk_ids[]']:checked").clone().appendTo("#bulk_form .bulk_ids");

      $("#bulk_form").submit();

      return false;
    }
  });
});
