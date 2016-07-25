package com.rabbitmq.authbackend.examples;

import com.rabbitmq.authbackend.AuthBackend;
import com.rabbitmq.authbackend.AuthServer;
import com.rabbitmq.client.Channel;
import com.rabbitmq.client.Connection;
import com.rabbitmq.client.ConnectionFactory;

import java.io.IOException;
import java.net.ConnectException;
import java.util.Date;

/**
 *
 */
public class Main {
    private static final ConnectionFactory FACTORY = new ConnectionFactory();
    private static final String EXCHANGE = "authentication";
    private static final AuthBackend BACKEND = new ExampleAuthBackend();

    public static void main(String[] args) throws IOException {

        FACTORY.setPort(Integer.parseInt(args[0]));
        try {
            while (true) {
                System.out.print(new Date() + " Connecting...");
                try {
                    Connection conn = FACTORY.newConnection();
                    Channel ch = conn.createChannel();
                    System.out.println(" done");

                    new AuthServer(BACKEND, ch, EXCHANGE).mainloop();
                    System.out.println(new Date() + " Connection died");
                }
                catch (ConnectException e) {
                    System.out.println(" failed");
                }
                Thread.sleep(1000);
            }

        } catch (Exception ex) {
            System.err.println("Main thread caught exception: " + ex);
            ex.printStackTrace();
            System.exit(1);
        }
    }
}
