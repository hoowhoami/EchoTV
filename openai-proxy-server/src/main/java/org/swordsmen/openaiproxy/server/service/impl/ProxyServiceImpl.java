package org.swordsmen.openaiproxy.server.service.impl;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.collections4.CollectionUtils;
import org.apache.commons.lang3.StringUtils;
import org.reactivestreams.Publisher;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ServerWebExchange;
import org.swordsmen.openaiproxy.channel.core.ChatMessage;
import org.swordsmen.openaiproxy.channel.core.ChatSessionFactory;
import org.swordsmen.openaiproxy.channel.core.config.ProxyProperties;
import org.swordsmen.openaiproxy.channel.core.model.BotType;
import org.swordsmen.openaiproxy.channel.core.model.ProxyRequest;
import org.swordsmen.openaiproxy.common.core.exception.BadRequestException;
import org.swordsmen.openaiproxy.common.core.exception.ForbiddenException;
import org.swordsmen.openaiproxy.common.core.exception.UnauthorizedException;
import org.swordsmen.openaiproxy.server.service.ProxyService;
import reactor.core.publisher.Flux;

import java.util.List;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Slf4j
@RequiredArgsConstructor
@Service
public class ProxyServiceImpl implements ProxyService {

    private final ProxyProperties proxyProperties;
    private final ChatSessionFactory chatSessionFactory;

    @Override
    public void checkAuth(ServerWebExchange exchange) {
        final ServerHttpRequest request = exchange.getRequest();
        final String authorization = request.getHeaders().getFirst("Authorization");
        log.info("Request authorization: {}", authorization);
        if (StringUtils.isBlank(authorization)) {
            throw new UnauthorizedException("Authorization is required");
        }
        if (!StringUtils.containsIgnoreCase(authorization, proxyProperties.getAuth())) {
            throw new ForbiddenException("Request forbidden");
        }
    }

    @Override
    public BotType parseBotType(ServerWebExchange exchange) {
        ServerHttpRequest serverHttpRequest = exchange.getRequest();
        String channel = serverHttpRequest.getHeaders().getFirst("X-Channel");
        log.info("Request channel: {}", channel);
        if (StringUtils.isBlank(channel)) {
            throw new BadRequestException("Missing header X-Channel");
        }
        BotType botType = BotType.of(channel);
        if (botType == null) {
            throw new BadRequestException("Invalid header value X-Channel: " + channel);
        }
        return botType;
    }

    @Override
    public Publisher<String> chat(ProxyRequest request) {
        List<ChatMessage> messages = request.getMessages();
        if (CollectionUtils.isEmpty(messages)) {
            return Flux.just("");
        }
        String question = messages.getLast().getContent();
        // 判断是否以特殊指令开头
        if (StringUtils.isBlank(question)) {
            return Flux.just("");
        }
        String botName = request.getBotType().getName();
        if (question.startsWith("/")) {
            botName = question.substring(1, question.indexOf(" "));
            question = question.substring(question.indexOf(" ") + 1);
        }
        if (proxyProperties.isPrintLog()) {
            log.info("Request question: {}", question);
        }
        return chatSessionFactory.getChatSession(request, botName).chat(request.getMessages());
    }


}
