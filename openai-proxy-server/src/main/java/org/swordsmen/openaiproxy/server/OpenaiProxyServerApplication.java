package org.swordsmen.openaiproxy.server;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * @author JLT
 * Create by 2024/4/2
 */
@SpringBootApplication(scanBasePackages = "org.swordsmen")
public class OpenaiProxyServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(OpenaiProxyServerApplication.class, args);
    }

}
