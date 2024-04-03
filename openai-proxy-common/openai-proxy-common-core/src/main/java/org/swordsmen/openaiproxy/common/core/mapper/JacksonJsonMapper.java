package org.swordsmen.openaiproxy.common.core.mapper;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.json.JsonReadFeature;
import com.fasterxml.jackson.core.json.JsonWriteFeature;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.google.common.collect.Lists;
import org.apache.commons.collections4.CollectionUtils;
import org.apache.commons.lang3.Validate;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * @author JLT
 * Create by 2024/3/29
 */
public final class JacksonJsonMapper {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private ObjectMapper objectMapper;

    private JacksonJsonMapper() {
        OBJECT_MAPPER.configure(SerializationFeature.FAIL_ON_EMPTY_BEANS, false);
        OBJECT_MAPPER.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
        OBJECT_MAPPER.setSerializationInclusion(JsonInclude.Include.NON_NULL);
    }

    private JacksonJsonMapper(ObjectMapper objectMapper) {
        this();
        Validate.notNull(objectMapper, "ObjectMapper must not be null");
        this.objectMapper = objectMapper;
    }

    public static JacksonJsonMapper create() {
        return new JacksonJsonMapper();
    }

    public static JacksonJsonMapper create(ObjectMapper objectMapper) {
        return new JacksonJsonMapper(objectMapper);
    }

    public JacksonJsonMapper configure(JsonReadFeature jsonReadFeature, boolean state) {
        buildJsonMapper();
        JsonParser.Feature feature = jsonReadFeature.mappedFeature();
        if (state) {
            objectMapper.enable(feature);
        } else {
            objectMapper.disable(feature);
        }
        return this;
    }

    public JacksonJsonMapper configure(JsonWriteFeature jsonWriteFeature, boolean state) {
        buildJsonMapper();
        JsonGenerator.Feature feature = jsonWriteFeature.mappedFeature();
        if (state) {
            objectMapper.enable(feature);
        } else {
            objectMapper.disable(feature);
        }
        return this;
    }

    public JacksonJsonMapper configure(SerializationFeature serializationFeature, boolean state) {
        buildJsonMapper();
        objectMapper.configure(serializationFeature, state);
        return this;
    }

    public JacksonJsonMapper configure(DeserializationFeature deserializationFeature, boolean state) {
        buildJsonMapper();
        objectMapper.configure(deserializationFeature, state);
        return this;
    }

    public JacksonJsonMapper configure(JsonInclude.Include include) {
        buildJsonMapper();
        objectMapper.setSerializationInclusion(include);
        return this;
    }

    public JacksonJsonMapper unicode() {
        return configure(JsonWriteFeature.ESCAPE_NON_ASCII, true);
    }

    private void buildJsonMapper() {
        if (objectMapper == null) {
            objectMapper = OBJECT_MAPPER.copy();
        }
    }

    private ObjectMapper getObjectMapper() {
        if (objectMapper != null) {
            return objectMapper;
        }
        return OBJECT_MAPPER;
    }

    /**
     * 对象转json
     *
     * @param object 对象
     * @param <T>    类型
     * @return json
     */
    public <T> String toJson(T object) {
        Validate.notNull(object, "Object must not be null");
        try {
            return getObjectMapper().writeValueAsString(object);
        } catch (JsonProcessingException e) {
            throw new UncheckedIOException("Failed to mapping object to json", e);
        }
    }

    /**
     * 对象转json
     *
     * @param object 对象
     * @param <T>    类型
     * @return 格式化后的json
     */
    public <T> String toJsonPretty(T object) {
        Validate.notNull(object, "Object must not be null");
        try {
            return getObjectMapper().writerWithDefaultPrettyPrinter().writeValueAsString(object);
        } catch (JsonProcessingException e) {
            throw new UncheckedIOException("Failed to mapping object to json", e);
        }
    }

    /**
     * json 转对象
     *
     * @param json  json
     * @param clazz 对象的class
     * @param <T>   期望的类型
     * @return 对象
     */
    public <T> T fromJson(String json, Class<T> clazz) {
        Validate.notNull(json, "Json must not be null");
        Validate.notNull(clazz, "Class must not be null");
        try {
            return getObjectMapper().readValue(json, clazz);
        } catch (IOException e) {
            throw new UncheckedIOException("Failed to mapping json to object", e);
        }
    }

    /**
     * json 转对象
     *
     * @param json          json
     * @param typeReference 对象类型的typeReference
     * @param <T>           期望的类型
     * @return 对象
     */
    public <T> T fromJson(String json, TypeReference<T> typeReference) {
        Validate.notNull(json, "Json must not be null");
        Validate.notNull(typeReference, "TypeReference must not be null");
        try {
            return getObjectMapper().readValue(json, typeReference);
        } catch (IOException e) {
            throw new UncheckedIOException("Failed to mapping json to object", e);
        }
    }

    /**
     * json 转List对象
     *
     * @param json json
     * @param <T>  期望的类型
     * @return 对象
     */
    public <T> List<T> fromJsonList(String json, Class<T> clazz) {
        Validate.notNull(json, "Json must not be null");
        Validate.notNull(clazz, "Class must not be null");
        try {
            final List<Map<String, Object>> maps = getObjectMapper().readValue(json, new TypeReference<List<Map<String, Object>>>() {
            });
            if (CollectionUtils.isEmpty(maps)) {
                return Lists.newArrayList();
            }
            final List<T> result = Lists.newArrayList();
            for (Map<String, Object> t : maps) {
                result.add(convert(t, clazz));
            }
            return result;
        } catch (IOException e) {
            throw new UncheckedIOException("Failed to mapping json to object", e);
        }
    }

    /**
     * json 对象转换为 java bean
     *
     * @param object object
     * @param clazz  clazz
     * @param <T>    T
     * @return java bean
     */
    public <T> T convert(Object object, Class<T> clazz) {
        Validate.notNull(object, "Object must not be null");
        Validate.notNull(clazz, "Class must not be null");
        return getObjectMapper().convertValue(object, clazz);
    }

    /**
     * json 对象转换为 java bean
     *
     * @param object        object
     * @param typeReference 对象类型的typeReference
     * @param <T>           T
     * @return java bean
     */
    public <T> T convert(Object object, TypeReference<T> typeReference) {
        Validate.notNull(object, "Object must not be null");
        Validate.notNull(typeReference, "TypeReference must not be null");
        return getObjectMapper().convertValue(object, typeReference);
    }

    /**
     * Converts a list of objects to a list of a specified type.
     *
     * @param list  the list of objects to be converted
     * @param clazz the class type to convert the objects to
     * @return the converted list of the specified type
     */
    public <T> List<T> convertList(List<?> list, Class<T> clazz) {
        Validate.notNull(list, "List must not be null");
        Validate.notNull(clazz, "Class must not be null");
        if (CollectionUtils.isEmpty(list)) {
            return Lists.newArrayList();
        }
        final List<T> result = Lists.newArrayList();
        for (Object t : list) {
            result.add(convert(t, clazz));
        }
        return result;
    }


    /**
     * 取json的节点
     * <p>
     * 支持 . 例如 user.name
     * </p>
     *
     * @param json     json
     * @param nodeName 想要取出的节点名称
     * @param clazz    节点的class
     * @param <T>      期望的类型
     * @return 节点
     */
    public <T> T getNode(String json, String nodeName, Class<T> clazz) {
        Validate.notNull(json, "Json must not be null");
        Validate.notNull(nodeName, "NodeName must not be null");
        Validate.notNull(clazz, "Class must not be null");
        try {
            final JsonNode node = new JacksonNodeParser(getObjectMapper()).getNode(json, nodeName);
            return Optional.ofNullable(node)
                    .map(n -> getObjectMapper().convertValue(n, clazz))
                    .orElse(null);
        } catch (Exception e) {
            throw new RuntimeException("Failed to get json node", e);
        }
    }

    /**
     * 取json的节点
     * <p>
     * 支持 . 例如 user.name
     * </p>
     *
     * @param json          json
     * @param nodeName      想要取出的节点名称
     * @param typeReference 节点类型的typeReference
     * @param <T>           期望的类型
     * @return 节点
     */
    public <T> T getNode(String json, String nodeName, TypeReference<T> typeReference) {
        Validate.notNull(json, "Json must not be null");
        Validate.notNull(nodeName, "NodeName must not be null");
        Validate.notNull(typeReference, "TypeReference must not be null");
        try {
            final JsonNode node = new JacksonNodeParser(getObjectMapper()).getNode(json, nodeName);
            return Optional.ofNullable(node)
                    .map(n -> getObjectMapper().convertValue(n, typeReference))
                    .orElse(null);
        } catch (Exception e) {
            throw new RuntimeException("Failed to get json node", e);
        }
    }


}
