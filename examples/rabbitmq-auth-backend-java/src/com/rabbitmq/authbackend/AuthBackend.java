package com.rabbitmq.authbackend;

/**
 * A Java-ish representation of the RabbitMQ authentication backend API
 */
public interface AuthBackend {
    public LoginResult login(String username);

    public LoginResult login(String username,
                             String password);

    boolean checkVhost(String username,
                       String vhost,
                       VHostPermission permission);

    boolean checkResource(String username,
                          String vhost,
                          String resourceName,
                          ResourceType resourceType,
                          ResourcePermission permission);
}
