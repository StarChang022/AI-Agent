/**
 * Custom JavaScript for accessibility improvements
 * 無障礙優化自訂 JavaScript
 */

(function() {
    'use strict';

    /**
     * 修正 Owl Carousel 導航按鈕的無障礙屬性
     * Fix accessibility attributes for Owl Carousel navigation buttons
     */
    function fixOwlCarouselAccessibility() {
        // 尋找所有 owl-next 按鈕
        const owlNextButtons = document.querySelectorAll('.owl-next');
        // 尋找所有 owl-prev 按鈕
        const owlPrevButtons = document.querySelectorAll('.owl-prev');

        // 修正 owl-next 按鈕
        owlNextButtons.forEach(function(button) {
            // 移除不相容的 role="presentation" 屬性
            button.removeAttribute('role');
            // 添加適當的 aria-label
            button.setAttribute('aria-label', '下一張');
            // 確保按鈕具有適當的 type 屬性
            if (!button.hasAttribute('type')) {
                button.setAttribute('type', 'button');
            }
        });

        // 修正 owl-prev 按鈕
        owlPrevButtons.forEach(function(button) {
            // 移除不相容的 role="presentation" 屬性
            button.removeAttribute('role');
            // 添加適當的 aria-label
            button.setAttribute('aria-label', '上一張');
            // 確保按鈕具有適當的 type 屬性
            if (!button.hasAttribute('type')) {
                button.setAttribute('type', 'button');
            }
        });

        // 修正 owl-dot 分頁點
        const owlDots = document.querySelectorAll('.owl-dot');
        owlDots.forEach(function(dot, index) {
            // 移除不相容的 role 屬性
            dot.removeAttribute('role');
            // 確保按鈕具有適當的 type 屬性
            if (!dot.hasAttribute('type')) {
                dot.setAttribute('type', 'button');
            }

            // 獲取該點所在的 carousel 容器
            const carousel = dot.closest('.owl-carousel');
            if (carousel) {
                // 計算該點在該 carousel 中的索引（相對於同一個 carousel 的其他點）
                const carouselDots = carousel.querySelectorAll('.owl-dot');
                const dotIndex = Array.from(carouselDots).indexOf(dot);
                const totalDots = carouselDots.length;

                // 添加 aria-label，說明這是第幾個分頁點
                dot.setAttribute('aria-label', '前往第 ' + (dotIndex + 1) + ' 張，共 ' + totalDots + ' 張');

                // 為活動的點添加 aria-current
                if (dot.classList.contains('active')) {
                    dot.setAttribute('aria-current', 'true');
                } else {
                    dot.removeAttribute('aria-current');
                }
            } else {
                // 如果找不到 carousel 容器，使用簡單的標籤
                dot.setAttribute('aria-label', '前往第 ' + (index + 1) + ' 張');
            }
        });
    }
    /**
     * 監聽 DOM 變化，自動為新生成的 owl-dot 元素添加無障礙屬性
     */
    function setupOwlDotObserver() {
        // 監聽整個文檔的變化
        const observer = new MutationObserver(function(mutations) {
            let shouldUpdate = false;

            mutations.forEach(function(mutation) {
                // 檢查是否有新增的節點
                mutation.addedNodes.forEach(function(node) {
                    if (node.nodeType === 1) { // Element node
                        // 檢查是否為 owl-dot 元素，或其父元素包含 owl-dot
                        if (node.classList && node.classList.contains('owl-dot')) {
                            shouldUpdate = true;
                        } else if (node.querySelector && node.querySelector('.owl-dot')) {
                            shouldUpdate = true;
                        }
                    }
                });
            });

            // 如果有相關變化，更新無障礙屬性
            if (shouldUpdate) {
                setTimeout(fixOwlCarouselAccessibility, 100);
            }
        });

        // 開始觀察
        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    }

    /**
     * 初始化函數
     */
    function init() {
        // 設置 MutationObserver
        setupOwlDotObserver();

        // 頁面載入後執行一次
        window.addEventListener('load', function() {
            setTimeout(fixOwlCarouselAccessibility, 500);
            // 再次延遲執行，確保動態生成的元素也被處理
            setTimeout(fixOwlCarouselAccessibility, 1500);
        });
    }

    // 等待 DOM 準備完成
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        // DOM 已經準備好了，立即執行
        init();
    }

})();
