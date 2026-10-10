package com.drivon.api.assistant.tools;

/**
 * A tool call with arguments that can't be used. The message goes back to the model, which can
 * correct the call, so it says what is wrong in plain words.
 */
public class ToolArgumentException extends RuntimeException {

  public ToolArgumentException(String message) {
    super(message);
  }
}
