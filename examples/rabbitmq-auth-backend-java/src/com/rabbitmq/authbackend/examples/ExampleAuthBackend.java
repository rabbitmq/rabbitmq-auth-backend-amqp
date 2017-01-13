package com.rabbitmq.authbackend.examples;

import com.rabbitmq.authbackend.AuthBackend;
import com.rabbitmq.authbackend.LoginResult;
import com.rabbitmq.authbackend.ResourcePermission;
import com.rabbitmq.authbackend.ResourceType;

/**
 *
 */
public class ExampleAuthBackend implements AuthBackend {
    private static final LoginResult ACCEPTED = new LoginResult(true, new String[]{"administrator"});
    private static final LoginResult REFUSED = new LoginResult(false);

    public LoginResult login(String username) {
        if (username.equals("smacmullen.eng.vmware.com")) {
            return ACCEPTED;
        }

        return REFUSED;
    }

    public LoginResult login(String username,
                             String password) {
        if (username.equals("simon") && password.equals("simon")) {
            return ACCEPTED;
        }

        return REFUSED;
    }

    public boolean checkVhost(String username,
                              String vhost) {
        return vhost.equals("/");
    }

    public boolean checkResource(String username,
                                 String vhost,
                                 String resourceName,
                                 ResourceType resourceType,
                                 ResourcePermission permission) {
        return true;
    }

    public boolean checkTopic(String username,
                              String vhost,
                              String resourceName,
                              ResourceType resourceType,
                              ResourcePermission permission,
                              String routingKey) {
        return routingKey.startsWith("a");
    }
}
