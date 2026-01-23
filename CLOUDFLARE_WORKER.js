export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    let targetUrl = url.searchParams.get('url');

    // 处理 CORS 预检请求 (OPTIONS)
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
          "Access-Control-Allow-Headers": "*",
          "Access-Control-Max-Age": "86400",
        },
      });
    }

    if (!targetUrl) {
      return new Response('MixTV 通用跨域代理\n使用说明: /?url=https://api.example.com/data', { 
        status: 400,
        headers: { "Content-Type": "text/plain; charset=utf-8" }
      });
    }

    try {
      // 构造转发请求的头部
      const newHeaders = new Headers(request.headers);
      
      // 剔除可能干扰目标的头部
      newHeaders.delete("host");
      newHeaders.delete("origin");
      newHeaders.delete("referer");

      // 智能识别：如果是豆瓣请求，则自动注入豆瓣所需的头部
      if (targetUrl.includes("douban.com") || targetUrl.includes("doubanio.com")) {
        newHeaders.set("Referer", "https://movie.douban.com/");
        newHeaders.set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36");
      } else {
        // 对于普通视频源，使用通用的 User-Agent
        newHeaders.set("User-Agent", request.headers.get("User-Agent") || "Mozilla/5.0 MixTV/1.0");
      }

      // 准备转发参数
      const fetchOptions = {
        method: request.method,
        headers: newHeaders,
        redirect: "follow",
      };

      // 如果有请求体，则进行转发 (支持 POST 搜索等)
      if (request.method !== "GET" && request.method !== "HEAD") {
        fetchOptions.body = await request.arrayBuffer();
      }

      const response = await fetch(targetUrl, fetchOptions);

      // 构造响应，注入 CORS 头部
      const modifiedResponse = new Response(response.body, response);
      modifiedResponse.headers.set("Access-Control-Allow-Origin", "*");
      modifiedResponse.headers.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
      modifiedResponse.headers.set("Access-Control-Allow-Headers", "*");
      modifiedResponse.headers.set("Access-Control-Expose-Headers", "*");
      
      // 移除安全限制，防止在部分环境下的显示问题
      modifiedResponse.headers.delete("content-security-policy");
      modifiedResponse.headers.delete("x-frame-options");

      return modifiedResponse;
    } catch (err) {
      return new Response('代理请求失败: ' + err.message, { 
        status: 500,
        headers: { "Access-Control-Allow-Origin": "*" }
      });
    }
  }
};