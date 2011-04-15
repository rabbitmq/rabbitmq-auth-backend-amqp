package com.rabbitmq.authbackend.examples;

import com.rabbitmq.authbackend.AuthBackend;
import com.rabbitmq.authbackend.LoginResult;
import com.rabbitmq.authbackend.ResourcePermission;
import com.rabbitmq.authbackend.ResourceType;
import com.rabbitmq.authbackend.VHostPermission;

/**
 *
 */
public class ExampleAuthBackend implements AuthBackend {
    public LoginResult login(String username) {
        if (username.equals("smacmullen.eng.vmware.com")) {
            return LoginResult.ACCEPTED;
        }

        return LoginResult.REFUSED;
    }

    public LoginResult login(String username,
                             String password) {
        if (username.equals("simon") && password.equals("simon")) {
            return LoginResult.ACCEPTED;
        }

        return LoginResult.REFUSED;
    }

    public boolean checkVhost(String username,
                              String vhost,
                              VHostPermission permission) {
        return vhost.equals("/");
    }

    public boolean checkResource(String username,
                                 String vhost,
                                 String resourceName,
                                 ResourceType resourceType,
                                 ResourcePermission permission) {
        return true;
    }
}
