package org.swordsmen.openaiproxy.channel.core.filter;

import org.apache.commons.lang3.StringUtils;
import org.springframework.core.io.buffer.DataBuffer;
import org.springframework.core.io.buffer.DataBufferUtils;
import org.springframework.http.HttpMethod;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.http.server.reactive.ServerHttpRequestDecorator;
import org.springframework.http.server.reactive.ServerHttpResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import org.springframework.web.server.WebFilter;
import org.springframework.web.server.WebFilterChain;
import org.swordsmen.openaiproxy.channel.core.HttpRequestHolder;
import org.swordsmen.openaiproxy.channel.core.model.ProxyRequest;
import org.swordsmen.openaiproxy.common.core.mapper.JacksonJsonMapper;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.nio.charset.StandardCharsets;
import java.util.Objects;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Component
public class ChangeResponseFilter implements WebFilter {

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        HttpRequestHolder.remove();

        ServerHttpResponse response = exchange.getResponse();
        ServerHttpRequest request = exchange.getRequest();
        response.getHeaders().add("Access-Control-Allow-Origin", "*");
        response.getHeaders().add("Access-Control-Allow-Credentials", "true");
        response.getHeaders().add("Access-Control-Allow-Methods", "GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS");
        response.getHeaders().add("Access-Control-Max-Age", "86400");
        response.getHeaders().add("Access-Control-Allow-Headers", "*");

        // 如果是OPTIONS则结束请求
        final HttpMethod method = request.getMethod();
        if (HttpMethod.OPTIONS == method) {
            return Mono.empty();
        }
        String contentType = request.getHeaders().getFirst("Content-Type");
        if (StringUtils.isBlank(contentType) || !contentType.contains("application/json")) {
            return chain.filter(exchange);
        }
        return DataBufferUtils.join(request.getBody())
                .flatMap(dataBuffer -> {
                    byte[] bytes = new byte[dataBuffer.readableByteCount()];
                    dataBuffer.read(bytes);
                    DataBufferUtils.release(dataBuffer);

                    String originalRequestBody = new String(bytes, StandardCharsets.UTF_8);
                    if (StringUtils.isNotBlank(originalRequestBody)) {
                        ProxyRequest proxyRequest = JacksonJsonMapper.create().fromJson(originalRequestBody, ProxyRequest.class);
                        HttpRequestHolder.set(proxyRequest);
                        if (proxyRequest != null && Objects.equals(true, proxyRequest.getStream())) {
                            response.getHeaders().set("Cache-Control", "no-cache");
                            response.getHeaders().set("Content-Type", "text/event-stream");
                            response.getHeaders().set("Access-Control-Allow-Origin", "*");
                        }
                    }
                    // Create a new request with the cached body
                    ServerHttpRequest newRequest = new ServerHttpRequestDecorator(request) {
                        @Override
                        public Flux<DataBuffer> getBody() {
                            return Flux.just(response.bufferFactory().wrap(bytes));
                        }
                    };
                    ServerWebExchange newExchange = exchange.mutate().request(newRequest).build();

                    return chain.filter(newExchange);
                });
    }

}
