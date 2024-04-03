package org.swordsmen.openaiproxy.channel.core;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.reactive.function.client.WebClient;
import org.swordsmen.openaiproxy.channel.core.config.ProxyProperties;
import org.swordsmen.openaiproxy.channel.core.model.ChatGptAnswer;
import org.swordsmen.openaiproxy.channel.core.model.Choices;
import org.swordsmen.openaiproxy.channel.core.model.Message;
import org.swordsmen.openaiproxy.common.core.mapper.JacksonJsonMapper;
import reactor.core.publisher.Flux;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

/**
 * @author JLT
 * Create by 2024/4/2
 */
@Slf4j
public abstract class BaseChatSession implements InitializingBean {

    @Autowired
    protected WebClient webClient;

    @Autowired
    protected ProxyProperties proxyProperties;


    protected abstract ChatBot chatBot();

    /**
     * 发送请求实现的方法
     *
     * @param question 本次询问的问题
     * @param messages 消息上下文,包含本次询问的问题和历史对话记录
     * @return 返回的消息流, 只包含文本消息和结束标志, 会自动转为gpt标准格式
     */
    protected abstract Flux<String> postChat(String question, List<ChatMessage> messages);


    /**
     * 会话是否结束的标记
     *
     * @param totalMsg 当前已经收到的全部回答
     * @param currMsg  流式传输当前回答
     * @return true or false
     */
    protected boolean isEnd(StringBuilder totalMsg, String currMsg) {
        return false;
    }

    /**
     * 权重
     */
    public int weight() {
        return 1;
    }


    public Flux<String> chat(List<ChatMessage> messages) {
        List<ChatMessage> chatMessages = new ArrayList<>();
        if (!ChatBot.isOpenAi(chatBot())) {
            // 非openai请求需要处理system消息,转为user请求
            messages.forEach(message -> {
                if (ChatRole.SYSTEM.equals(message.getRole())) {
                    chatMessages.add(ChatMessage.build(ChatRole.USER, message.getContent()));
                    chatMessages.add(ChatMessage.build(ChatRole.ASSISTANT, "好的"));
                } else {
                    chatMessages.add(message);
                }
            });
        } else {
            chatMessages.addAll(messages);
        }
        Flux<String> webFlux = postChat(messages.getLast().getContent(), chatMessages);
        if (ChatBot.isOpenAi(chatBot())) {
            return webFlux;
        }
        // 转换为gpt标准格式
        String id = UUID.randomUUID().toString();
        StringBuilder sb = new StringBuilder();
        Flux<String> result;
        if (this.chatBot().isStream()) {
            result = webFlux.map(data -> {
                if (this.isEnd(sb, data)) {
                    return "[DONE]";
                }
                sb.append(data);
                ChatGptAnswer answer = new ChatGptAnswer();
                answer.setId(id);
                answer.setObject("chat.completion.chunk");
                answer.setCreated(System.currentTimeMillis());
                answer.setModel("gpt-35-turbo");
                Choices choices = new Choices();
                choices.setIndex(0);
                Message message = new Message();
                message.setRole("assistant");
                message.setContent(data);
                choices.setDelta(message);
                answer.setChoices(Collections.singletonList(choices));
                return JacksonJsonMapper.create().toJson(answer);
            });
        } else {
            result = webFlux.map(data -> {
                ChatGptAnswer answer = new ChatGptAnswer();
                Choices choices = new Choices();
                Message message = new Message();
                answer.setId(id);
                answer.setObject("chat.completion.chunk");
                answer.setCreated(System.currentTimeMillis());
                answer.setModel("gpt-35-turbo");
                message.setRole("assistant");
                message.setContent(data);
                choices.setMessage(message);
                choices.setFinishReason("stop");
                answer.setChoices(Collections.singletonList(choices));
                sb.append(data);
                return JacksonJsonMapper.create().toJson(answer);
            });
        }
        return result.doOnComplete(() -> {
            if (proxyProperties.isPrintLog()) {
                log.info("AI回答: {}", sb);
            }
        }).doOnError(e -> {
            log.error("AI回答异常", e);
        });

    }

    @Override
    public void afterPropertiesSet() throws Exception {

    }

}
