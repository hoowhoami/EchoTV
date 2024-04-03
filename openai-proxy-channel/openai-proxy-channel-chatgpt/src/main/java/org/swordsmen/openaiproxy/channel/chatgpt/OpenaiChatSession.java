package org.swordsmen.openaiproxy.channel.chatgpt;

import org.apache.commons.lang3.StringUtils;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.swordsmen.openaiproxy.channel.core.BaseChatSession;
import org.swordsmen.openaiproxy.channel.core.ChatBot;
import org.swordsmen.openaiproxy.channel.core.ChatMessage;
import org.swordsmen.openaiproxy.channel.core.GptModel;
import org.swordsmen.openaiproxy.channel.core.HttpRequestHolder;
import org.swordsmen.openaiproxy.channel.core.config.OpenaiProperties;
import org.swordsmen.openaiproxy.channel.core.config.ProxyProperties;
import org.swordsmen.openaiproxy.channel.core.model.ProxyRequest;
import org.swordsmen.openaiproxy.common.core.mapper.JacksonJsonMapper;
import org.swordsmen.openaiproxy.common.core.util.HttpClientUtils;
import reactor.core.publisher.Flux;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@ConditionalOnProperty(name = "proxy.openai.enabled", havingValue = "true", matchIfMissing = true)
@Component("openai")
public class OpenaiChatSession extends BaseChatSession {

    protected String url;
    protected OpenaiProperties openaiProperties;

    @Override
    protected ChatBot chatBot() {
        return ChatBot.OPEN_AI;
    }

    @Override
    protected Flux<String> postChat(String question, List<ChatMessage> messages) {
        Map<String, Object> params = buildParams(messages, false);
        final String response = HttpClientUtils.getInstance().postJson(url, JacksonJsonMapper.create().toJson(params), getHeader(), null, null, String.class);
        if (response == null) {
            return Flux.empty();
        }
        return Flux.just(response);
    }

    protected Map<String, Object> buildParams(List<ChatMessage> messages, boolean stream) {
        ProxyRequest request = HttpRequestHolder.get();
        Map<String, Object> params = new HashMap<>();
        params.put("messages", messages);
        params.put("model", request.getModel());
        params.put("temperature", request.getTemperature());
        params.put("top_p", request.getTopP());
        params.put("presence_penalty", request.getPresencePenalty());
        params.put("frequency_penalty", request.getFrequencyPenalty());
        params.put("stream", stream);
        params.put("tools", request.getTools());
        return params;
    }

    protected Map<String, String> getHeader() {
        Map<String, String> headers = new HashMap<>();
        headers.put("Authorization", "Bearer " + openaiProperties.getApiKey());
        return headers;
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        this.openaiProperties = proxyProperties.getOpenai();
        this.url = openaiProperties.getBaseUrl() + "/v1/chat/completions";
    }

}
