document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll("[data-remote-btn]").forEach(function (button) {
    button.addEventListener("click", function () {
      // 從 data-target 屬性中獲取目標元素的選擇器
      const targetSelector = button.getAttribute("data-target");

      // 使用該選擇器查找目標元素
      const targetElement = document.querySelector(targetSelector);

      // 如果找到目標元素，則觸發其點擊事件
      if (targetElement) {
        targetElement.click();
      }
    });
  });
});
