import Swal from "sweetalert2";
window.Swal = Swal;
import Rails from "@rails/ujs";

document.addEventListener("DOMContentLoaded", function () {
  // 覆蓋alert
  window.alert = function (message) {
    Swal.fire({
      title: message,
      icon: "info",
      confirmButtonText: "確定",
    });
  };
});

Rails.confirm = function (message, element) {
  const confirmed = window.confirm(message);
  if (!confirmed) {
    // 如果用戶沒有確認，則阻止後續行為
    return false;
  }

  // 用戶確認了操作，繼續執行
  return true;
};

// 使用SweetAlert2替代原生confirm
Rails.confirm = function (message, element, callback) {
  Swal.fire({
    title: message,
    icon: "warning",
    showCancelButton: true,
    confirmButtonText: "Yes",
    cancelButtonText: "No",
  }).then((result) => {
    if (result.value) {
      // 用戶確認操作
      element.removeAttribute("data-confirm"); // 移除data-confirm屬性以避免重複觸發
      element.click(); // 重新觸發元素的點擊事件
    }
  });

  return false; // 阻止原始事件的執行
};

document.addEventListener("DOMContentLoaded", () => {
  document.body.addEventListener(
    "click",
    (event) => {
      const element = event.target.closest("[data-confirm]");
      if (!element) return;

      // 阻止原始事件，直到SweetAlert2確認對話框被處理
      event.preventDefault();
      Rails.confirm(element.getAttribute("data-confirm"), element);
    },
    false
  );
});
