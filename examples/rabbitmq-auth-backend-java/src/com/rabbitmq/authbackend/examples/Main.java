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
    public static void main(String[] args) throws IOException {
        try {
            ConnectionFactory factory = new ConnectionFactory();
            Connection conn = factory.newConnection();
            Channel ch = conn.createChannel();
            new AuthServer(new ExampleAuthBackend(), ch).mainloop();
            System.out.println("Auth server listening");

        } catch (Exception ex) {
            System.err.println("Main thread caught exception: " + ex);
            ex.printStackTrace();
            System.exit(1);
        }
    }
}
