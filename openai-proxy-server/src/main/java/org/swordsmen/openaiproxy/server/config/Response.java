package org.swordsmen.openaiproxy.server.config;

import lombok.Data;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Data
public class Response<T> {

    private Integer code;
    private String message;
    private T data;

    public static <V> Response<V> ok() {
        final Response<V> rs = new Response<>();
        rs.setCode(0);
        rs.setMessage("success");
        return rs;
    }

    public static <V> Response<V> ok(V data) {
        final Response<V> rs = new Response<>();
        rs.setCode(0);
        rs.setMessage("success");
        rs.setData(data);
        return rs;
    }

    public static <V> Response<V> error(int code, String message) {
        final Response<V> rs = new Response<>();
        rs.setCode(code);
        rs.setMessage(message);
        return rs;
    }

    public static <V> Response<V> error(String message) {
        return error(-1, message);
    }

}
