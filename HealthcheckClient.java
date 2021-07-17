// vim: set sw=4 ts=4 tw=80 noexpandtab:

// https://wiki.vg/Protocol

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;

public class HealthcheckClient {
  String host = "127.0.0.1";
  int port;
  Socket socket;

  OutputStream outbound;
  InputStream inbound;

  HealthcheckClient(int port) throws IOException {
    this.port = port = port > 0 ? port : 25565;
    socket = new Socket();
    socket.connect(new InetSocketAddress(host, port), 1000);
    outbound = socket.getOutputStream();
    inbound = socket.getInputStream();
  }

  public static void main(String[] args) {
    int status = 0;
    int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "0"));
    try {
      status = new HealthcheckClient(port).run() ? 0 : 1;
    } catch (IOException e) {
      e.printStackTrace();
      status = 2;
    }
    System.exit(status);
  }

  boolean run() throws IOException {
    outbound.write(createLegacyServerListPing());
    outbound.flush();

    return handleLegacyServerListPong(inbound.readAllBytes());
  }

  static byte[] createLegacyServerListPing() {
    return new byte[] {
      (byte) 0xFE, 0x01,
    };
  }

  static boolean handleLegacyServerListPong(byte[] response) {
    if (response[0] != (byte) 0xFF) {
      System.out.println("Expected 0xff at start of response!");
      return false;
    }
    int size = response[1] << 8 | response[2];
    if (response.length != 2 * size + 3) {
      System.out.format("Expected %d characters, got %d!\n", size, response.length - 3);
      return false;
    }

    return true;
  }
}
