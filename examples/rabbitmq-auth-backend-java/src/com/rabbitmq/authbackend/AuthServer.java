package com.rabbitmq.authbackend;

import com.rabbitmq.client.AMQP;
import com.rabbitmq.client.Channel;
import com.rabbitmq.client.QueueingConsumer;
import com.rabbitmq.client.RpcServer;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.util.Map;

/**
 *
 */
public class AuthServer extends RpcServer {
    private AuthBackend authBackend;

    public AuthServer(AuthBackend authBackend, Channel channel) throws IOException {
        super(channel);
        this.authBackend = authBackend;
        channel.queueBind(getQueueName(), "amqp-auth", "");
    }

    public byte[] handleCall(QueueingConsumer.Delivery request,
                             AMQP.BasicProperties replyProperties)
    {
        Map<String, Object> headers = request.getProperties().getHeaders();
        String action = get("action", headers);

        if (action.equals("login")) {
            return bytes(
                    authBackend.login(get("username", headers),
                                      get("password", headers)).toString().toLowerCase());
        }
        else if (action.equals("check_vhost")) {
            return bool(authBackend.checkVhost(
                    get("username", headers),
                    get("vhost", headers),
                    VHostPermission.valueOf(getU("permission", headers))));
        }
        else if (action.equals("check_resource")) {
            return bool(authBackend.checkResource(
                    get("username", headers),
                    get("vhost", headers),
                    get("name", headers),
                    ResourceType.valueOf(getU("resource", headers)),
                    ResourcePermission.valueOf(getU("permission", headers))));
        }

        throw new RuntimeException("Unexpected action " + action);
    }

    private String getU(String key, Map<String, Object> headers) {
        return get(key,headers).toUpperCase();
    }

    private String get(String key, Map<String, Object> headers) {
        return headers.get(key).toString();
    }

    private byte[] bytes(String s) {
        try {
            return s.getBytes("utf-8");
        } catch (UnsupportedEncodingException e) {
            throw new RuntimeException(e);
        }
    }

    private byte[] bool(boolean b) {
        return bytes(b ? "allow" : "deny");
    }
}
