package org.swordsmen.openaiproxy.server.controller;

import lombok.RequiredArgsConstructor;
import org.reactivestreams.Publisher;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ServerWebExchange;
import org.swordsmen.openaiproxy.channel.core.model.BotType;
import org.swordsmen.openaiproxy.channel.core.model.ProxyRequest;
import org.swordsmen.openaiproxy.server.service.ProxyService;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@RequiredArgsConstructor
@RestController
public class ProxyController {

    private final ProxyService proxyService;

    @RequestMapping("/v1/chat/completions")
    public Publisher<String> chat(@RequestBody ProxyRequest request, ServerWebExchange exchange) {
        proxyService.checkAuth(exchange);
        final BotType botType = proxyService.parseBotType(exchange);
        request.setBotType(botType);
        return proxyService.chat(request);
    }

}
