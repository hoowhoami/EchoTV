package org.swordsmen.openaiproxy.channel.core;

import org.swordsmen.openaiproxy.channel.core.model.ProxyRequest;

/**
 * @author JLT
 * Create by 2024/4/3
 */
public class HttpRequestHolder {

    public static final ThreadLocal<ProxyRequest> REQUEST_HOLDER = new ThreadLocal<>();

    public static void set(ProxyRequest request) {
        REQUEST_HOLDER.set(request);
    }

    public static ProxyRequest get() {
        return REQUEST_HOLDER.get();
    }

    public static void remove() {
        REQUEST_HOLDER.remove();
    }

}
