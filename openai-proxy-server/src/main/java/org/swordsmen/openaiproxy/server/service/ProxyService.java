package org.swordsmen.openaiproxy.server.service;

import org.reactivestreams.Publisher;
import org.springframework.web.server.ServerWebExchange;
import org.swordsmen.openaiproxy.channel.core.model.BotType;
import org.swordsmen.openaiproxy.channel.core.model.ProxyRequest;

/**
 * @author JLT
 * Create by 2024/4/3
 */
public interface ProxyService {

    void checkAuth(ServerWebExchange exchange);

    BotType parseBotType(ServerWebExchange exchange);

    Publisher<String> chat(ProxyRequest request);

}
