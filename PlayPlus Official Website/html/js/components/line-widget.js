/**
 * Line Widget Component
 * 可重複使用的 Line QR Code 彈出視窗組件
 */
class LineWidget {
    constructor() {        
        this.init();
    }

    init() {
        // 建立主容器
        const container = document.createElement('div');
        container.innerHTML = this.getHTML();
        
        // 插入到 body
        document.body.appendChild(container);
    }

    getHTML() {
        return `
            <!-- Line Widget -->
            <a href="line://ti/p/@383opidj" target="_blank" class="line-widget">
                <img src="/images/icon-line-logo.webp" alt="Line Logo" class="line-logo-img">
            </a>
        `;
    }
}

document.addEventListener('DOMContentLoaded', function() {
    new LineWidget();
});
