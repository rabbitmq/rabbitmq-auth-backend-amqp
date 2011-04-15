package com.rabbitmq.authbackend.examples;

import com.rabbitmq.authbackend.AuthServer;
import com.rabbitmq.client.Channel;
import com.rabbitmq.client.Connection;
import com.rabbitmq.client.ConnectionFactory;

import java.io.IOException;

/**
 *
 */
public class Main {
    private static final ConnectionFactory FACTORY = new ConnectionFactory();
    private static final String EXCHANGE = "authentication";

    public static void main(String[] args) throws IOException {

        try {
            Connection conn = FACTORY.newConnection();
            Channel ch = conn.createChannel();
            new AuthServer(new ExampleAuthBackend(), ch, EXCHANGE).mainloop();

        } catch (Exception ex) {
            System.err.println("Main thread caught exception: " + ex);
            ex.printStackTrace();
            System.exit(1);
        }
    }
}
