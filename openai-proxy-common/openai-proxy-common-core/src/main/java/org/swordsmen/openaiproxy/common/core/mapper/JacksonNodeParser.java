package org.swordsmen.openaiproxy.common.core.mapper;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.JsonNodeType;
import com.google.common.base.Splitter;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.math.NumberUtils;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * @author JLT
 * Create by 2024/3/29
 */
class JacksonNodeParser {

    private static final String SEPARATOR = ".";
    private static final String ARRAY_SEPARATOR_BEGIN = "[";
    private static final String ARRAY_SEPARATOR_END = "]";
    private static final String ARRAY_NODE_NAME_PATTERN_REG = "[a-zA-Z0-9\\u4e00-\\u9fa5-_]*\\[[0-9]+\\]";
    private static final Pattern ARRAY_NODE_NAME_PATTERN = Pattern.compile(ARRAY_NODE_NAME_PATTERN_REG);

    private final ObjectMapper objectMapper;

    JacksonNodeParser(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }


    JsonNode getNode(String content, String nodeName) {
        try {
            JsonNode next = null;
            if (StringUtils.isBlank(nodeName)) {
                return null;
            } else {
                JsonNode node = objectMapper.readTree(content);
                for (String name : Splitter.on(SEPARATOR).trimResults().split(nodeName)) {
                    final Matcher matcher = ARRAY_NODE_NAME_PATTERN.matcher(name);
                    if (matcher.matches()) {
                        // 处理带数组下标的 node name
                        // 例如 books[0]
                        final String array = StringUtils.substringBeforeLast(name, ARRAY_SEPARATOR_BEGIN);
                        node = node.get(array);
                        final JsonNodeType nodeType = node.getNodeType();
                        if (nodeType == JsonNodeType.ARRAY) {
                            // 数组，特殊处理
                            final String arrayIndex = StringUtils.substringBetween(name, ARRAY_SEPARATOR_BEGIN, ARRAY_SEPARATOR_END);
                            if (NumberUtils.isCreatable(arrayIndex)) {
                                final int index = NumberUtils.toInt(arrayIndex);
                                next = node.get(index);
                            } else {
                                next = node.get(name);
                            }
                        } else {
                            next = node.get(name);
                        }
                    } else {
                        next = node.get(name);
                    }
                    if (next != null) {
                        node = next;
                    }
                }
            }
            return next;
        } catch (IOException e) {
            throw new UncheckedIOException("Failed to get node", e);
        }
    }

}
