package com.rabbitmq.authbackend.examples;

import com.rabbitmq.client.Connection;
import com.rabbitmq.client.ConnectionFactory;

import java.io.IOException;

public class TestMain {
    public static void main(String[] args) throws IOException {
        ConnectionFactory factory = new ConnectionFactory();
        factory.setUsername("simon");
        factory.setPassword("simon");
        Connection conn = factory.newConnection();
        conn.close();
    }
}
