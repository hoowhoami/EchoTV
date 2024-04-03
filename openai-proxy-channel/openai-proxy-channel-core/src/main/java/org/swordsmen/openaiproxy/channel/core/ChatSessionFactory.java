package org.swordsmen.openaiproxy.channel.core;

import jakarta.annotation.Resource;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.stereotype.Component;
import org.swordsmen.openaiproxy.channel.core.model.BotType;
import org.swordsmen.openaiproxy.channel.core.model.ProxyRequest;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Component
public class ChatSessionFactory implements InitializingBean {

    @Resource
    private Map<String, BaseChatSession> chatSessionMap;

    @Resource
    private List<BaseChatSession> allChatSession;

    public BaseChatSession getChatSession(ProxyRequest request, String botName) {
        final BotType botType = BotType.of(botName);
        if (BotType.ALL == botType) {
            // 轮询获取
            botName = PollingChatSessionHolder.getBotName();
        }
        botName = botName + (Objects.equals(true, request.getStream()) ? "Stream" : "");
        return chatSessionMap.get(botName);
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        allChatSession
                .forEach(session -> {
                    int weight = session.weight();
                    String botName = session.chatBot().getName();
                    if (botName.endsWith("stream")) {
                        return;
                    }
                    for (int i = 0; i < weight; i++) {
                        PollingChatSessionHolder.POLLING_CHAT_BOT_NAMES.add(botName);
                    }
                });
    }

    public static class PollingChatSessionHolder {
        private static final List<String> POLLING_CHAT_BOT_NAMES = new ArrayList<>();
        private static final AtomicInteger INDEX = new AtomicInteger(0);

        public static String getBotName() {
            return POLLING_CHAT_BOT_NAMES.get(INDEX.getAndIncrement() % POLLING_CHAT_BOT_NAMES.size());
        }
    }

}
