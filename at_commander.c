// C library headers
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
// Linux headers
#include <fcntl.h> // Contains file controls like O_RDWR
#include <errno.h> // Error integer and strerror() function
#include <termios.h> // Contains POSIX terminal control definitions
#include <unistd.h> // write(), read(), close()

int write_log(char*);
void replace_newline_carriage(char*);

int main(int argc, char* argv[]) {
  if (argc < 2) {
    printf("Usage: %s <at-command>\n", argv[0]);
    exit(-1);
  }
  int serial_port = open("/dev/ttyUSB4", O_RDWR);
  // Check for errors
  if (serial_port < 0) {
      printf("Error %i from open: %s\n", errno, strerror(errno));
      exit(1);
  }
  struct termios tty;

  // Read in existing settings, and handle any error
  if(tcgetattr(serial_port, &tty) != 0) {
      printf("Error %i from tcgetattr: %s\n", errno, strerror(errno));
      return 1;
  }

  tty.c_cflag &= ~PARENB; // Clear parity bit, disabling parity (most common)
  tty.c_cflag &= ~CSTOPB; // Clear stop field, only one stop bit used in communication (most common)
  tty.c_cflag &= ~CSIZE; // Clear all bits that set the data size
  tty.c_cflag |= CS8; // 8 bits per byte (most common)
  tty.c_cflag &= ~CRTSCTS; // Disable RTS/CTS hardware flow control (most common)
  tty.c_cflag |= CREAD | CLOCAL; // Turn on READ & ignore ctrl lines (CLOCAL = 1)

  tty.c_lflag &= ~ICANON;
  tty.c_lflag &= ~ECHO; // Disable echo
  tty.c_lflag &= ~ECHOE; // Disable erasure
  tty.c_lflag &= ~ECHONL; // Disable new-line echo
  tty.c_lflag &= ~ISIG; // Disable interpretation of INTR, QUIT and SUSP
  tty.c_iflag &= ~(IXON | IXOFF | IXANY); // Turn off s/w flow ctrl
  tty.c_iflag &= ~(IGNBRK|BRKINT|PARMRK|ISTRIP|INLCR|IGNCR|ICRNL); // Disable any special handling of received bytes

  tty.c_oflag &= ~OPOST; // Prevent special interpretation of output bytes (e.g. newline chars)
  tty.c_oflag &= ~ONLCR; // Prevent conversion of newline to carriage return/line feed
  // tty.c_oflag &= ~OXTABS; // Prevent conversion of tabs to spaces (NOT PRESENT ON LINUX)
  // tty.c_oflag &= ~ONOEOT; // Prevent removal of C-d chars (0x004) in output (NOT PRESENT ON LINUX)

  tty.c_cc[VTIME] = 5;    // Wait for up to 1s (10 deciseconds), returning as soon as any data is received.; 5 sek ^= 50
  tty.c_cc[VMIN] = 80;

  // Set in/out baud rate to be 9600
  cfsetispeed(&tty, B9600);
  cfsetospeed(&tty, B9600);

  // Save tty settings, also checking for error
  if (tcsetattr(serial_port, TCSANOW, &tty) != 0) {
      printf("Error %i from tcsetattr: %s\n", errno, strerror(errno));
      return 1;
  }

  // Write to serial port
  //unsigned char msg[] = { 'a', 't', '+', 'c', 'g', 'p', 'a', 'd', 'd', 'r', '=', '1', '\r' };
  unsigned int argv1_len = strlen(argv[1]);
  char msg[argv1_len+2]; // unsigned char
  strcpy(msg, argv[1]); 
  write_log(msg);
  strcat(msg, "\r");
  
  write(serial_port, msg, strlen(msg)); // sizeof()
  
  // Allocate memory for read buffer, set size according to your needs
  char read_buf [256];

  // Normally you wouldn't do this memset() call, but since we will just receive
  // ASCII data for this example, we'll set everything to 0 so we can
  // call printf() easily.
  memset(&read_buf, '\0', sizeof(read_buf));

  // Read bytes. The behaviour of read() (e.g. does it block?,
  // how long does it block for?) depends on the configuration
  // settings above, specifically VMIN and VTIME
  int num_bytes = read(serial_port, &read_buf, sizeof(read_buf));

  // n is the number of bytes read. n may be 0 if no bytes were received, and can also be -1 to signal an error.
  if (num_bytes < 0) {
      printf("Error reading: %s", strerror(errno));
      close(serial_port);
      return 1;
  }else if (num_bytes == 0) {
      printf("0");
      close(serial_port);
      return 1;
  }

  // Here we assume we received ASCII data, but you might be sending raw bytes (in that case, don't try and
  // print it to the screen like this!)
  replace_newline_carriage(read_buf);
  printf("Read %i bytes. Received message: %s\n", num_bytes, read_buf);
  //printf("%s", read_buf); 
 
  
  write_log(read_buf);

  close(serial_port);
  return 0; // success
}

int write_log(char* message) {
    // Öffne die Log-Datei im Anhänge-Modus
    int log_file = open("/root/autostart/at_commander_log.log", O_WRONLY | O_APPEND | O_CREAT, 0644);
    if (log_file == -1) {
        perror("Fehler beim Öffnen der Log-Datei");
        return -1;
    }

    // Hole das aktuelle Datum und die Uhrzeit
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    char time_buffer[26]; // Puffer für Datum und Uhrzeit
    strftime(time_buffer, 26, "%04Y-%02m-%02d %02H:%02M:%02S", tm_info);

    // Baue die vollständige Log-Nachricht auf
    char log_entry[512]; // Großer Puffer für das Datum und die Nachricht
    snprintf(log_entry, sizeof(log_entry), "[%s] %s\n", time_buffer, message);

    // Schreibe die Log-Nachricht in die Datei
    write(log_file, log_entry, strlen(log_entry));

    // Schließe die Log-Datei
    close(log_file);
    return 0;
}

void replace_newline_carriage(char* str) {
    int len = strlen(str);
    
    for (int i = 0; i < len - 1; i++) {
        if (str[i] == '\n' || str[i] == '\r') {
            str[i] = ' ';
        }
    }

    // Letztes Zeichen nicht ändern, wenn es \n ist
    if (str[len - 1] == '\n') {
        str[len - 1] = ' ';
    } else if (str[len - 1] == '\r') {
        str[len - 1] = ' '; // Falls das letzte Zeichen \r ist, ersetze es.
    }
}