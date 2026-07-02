/**
 * WebMCP Support for PlayPlus
 * This script provides tools for AI agents to interact with the website.
 */
if (navigator.modelContext && navigator.modelContext.provideContext) {
    navigator.modelContext.provideContext({
        tools: [
            {
                name: "get_service_info",
                description: "Get information about PlayPlus digital transformation services.",
                inputSchema: {
                    type: "object",
                    properties: {
                        serviceType: {
                            type: "string",
                            enum: ["internal-systems", "web-design", "app", "chatbot"],
                            description: "The type of service to get information about."
                        }
                    }
                },
                execute: async (args) => {
                    const serviceMap = {
                        "internal-systems": "我們協助企業盤點流程，客製化內部管理系統。",
                        "web-design": "打造具有品牌敘事與 SEO 友善的品牌官網。",
                        "app": "開發滿足行動場景的客製化 APP。",
                        "chatbot": "設計自動化客服與互動腳本的聊天機器人。"
                    };
                    return { content: serviceMap[args.serviceType] || "請參考我們的服務項目頁面。" };
                }
            },
            {
                name: "contact_us",
                description: "Redirect the user to the contact page or provide contact info.",
                execute: async () => {
                    // Note: In some agent environments, window.location might be restricted.
                    // Providing the URL as content is a fallback.
                    window.location.href = "contact.html";
                    return { content: "正在引導你前往聯繫頁面 (contact.html)。" };
                }
            }
        ]
    });
}
