package org.swordsmen.openaiproxy.channel.chatgpt;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.BodyInserters;
import org.swordsmen.openaiproxy.channel.core.ChatBot;
import org.swordsmen.openaiproxy.channel.core.ChatMessage;
import reactor.core.publisher.Flux;

import java.util.List;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@ConditionalOnProperty(name = "proxy.openai.enabled", havingValue = "true", matchIfMissing = true)
@Component("openaiStream")
public class OpenaiStreamChatSession extends OpenaiChatSession {

    @Override
    protected ChatBot chatBot() {
        return ChatBot.OPEN_STREAM_AI;
    }

    @Override
    protected Flux<String> postChat(String question, List<ChatMessage> messages) {
        return webClient.post()
                .uri(url)
                .headers(httpHeaders -> getHeader().forEach(httpHeaders::add))
                .contentType(MediaType.APPLICATION_JSON)
                .body(BodyInserters.fromValue(buildParams(messages, true)))
                .retrieve()
                .bodyToFlux(String.class);
    }

}
