package org.swordsmen.openaiproxy.channel.core.config;

import io.netty.handler.ssl.SslContext;
import io.netty.handler.ssl.SslContextBuilder;
import io.netty.handler.ssl.util.InsecureTrustManagerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.reactive.ClientHttpConnector;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.ExchangeStrategies;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.socket.client.ReactorNettyWebSocketClient;
import org.springframework.web.reactive.socket.client.WebSocketClient;
import reactor.netty.http.client.HttpClient;

import javax.net.ssl.SSLException;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Configuration
public class WebClientConfig {

    public final static int BYTE_COUNT = 1024 * 1024 * 10;


    @Bean
    public WebClient webClient() throws SSLException {
        SslContext sslContext = SslContextBuilder.forClient()
                .trustManager(InsecureTrustManagerFactory.INSTANCE)
                .build();
        // 创建 HttpClient 对象
        HttpClient httpClient = HttpClient.create()
                .secure(sslContextSpec -> sslContextSpec.sslContext(sslContext));

        // 创建 ClientHttpConnector 对象
        ClientHttpConnector connector = new ReactorClientHttpConnector(httpClient);

        // 创建 ExchangeStrategies 对象，用于指定 HTTP 请求和响应转换的策略
        ExchangeStrategies exchangeStrategies = ExchangeStrategies.builder()
                .codecs(configurer -> configurer.defaultCodecs().maxInMemorySize(BYTE_COUNT))
                .build();

        return WebClient.builder()
                .clientConnector(connector)
                .exchangeStrategies(exchangeStrategies)
                .build();
    }

    @Bean
    public WebSocketClient webSocketClient() {
        return new ReactorNettyWebSocketClient();
    }

}
