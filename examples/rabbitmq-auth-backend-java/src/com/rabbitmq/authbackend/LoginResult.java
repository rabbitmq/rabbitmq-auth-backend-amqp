package com.rabbitmq.authbackend;

public class LoginResult {
    public LoginResult(boolean success) {
        this(success, new String[]{});
    }

    public LoginResult(boolean success, String[] tags) {
        this.success = success;
        this.tags = tags;
    }

    private boolean success;
    private String[] tags;

    public boolean isSuccess() {
        return success;
    }

    public void setSuccess(boolean success) {
        this.success = success;
    }

    public String[] getTags() {
        return tags;
    }

    public void setTags(String[] tags) {
        this.tags = tags;
    }

    public String toString() {
        if (success) {
            String r = "";
            for (int i = 0; i < tags.length; i++) {
                r += tags[i] + ",";
            }
            return r;
        }
        else {
            return "refused";
        }
    }
}
