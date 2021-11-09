#define ACCUMULATOR_COMPARE 2
#include <cstdio>
#include "Veurones.h"

// int mess[] = {
//   // 0, 0x90, 60, 60,
//   // 60*(int)CLOCKS_PER_FRAME, 0x80, 60, 0,
//   0*(int)CLOCKS_PER_FRAME, 0x93, 14, 60,
//   30*(int)CLOCKS_PER_FRAME, 0x93, 15, 60,
//   60*(int)CLOCKS_PER_FRAME, 0x93, 16, 60,
//   90*(int)CLOCKS_PER_FRAME, 0x93, 17, 60,
//   120*(int)CLOCKS_PER_FRAME, 0x93, 18, 60,
//   150*(int)CLOCKS_PER_FRAME, 0x93, 4, 60,
//   180*(int)CLOCKS_PER_FRAME, 0x93, 5, 60,
//   210*(int)CLOCKS_PER_FRAME, 0x93, 6, 60,
//   240*(int)CLOCKS_PER_FRAME, 0x93, 7, 60,
//   270*(int)CLOCKS_PER_FRAME, 0x93, 8, 60,
//   300*(int)CLOCKS_PER_FRAME, 0x93, 10, 0
// };

int mess[] = {
  0x55, 0xAA
};

char stringbuff[256];
size_t string_idx = 0;

int messageManagerStatic(int uart_status, int* uart_in, int uart_out, bool print_strings) {
  #define LEN_PACKET 3

  static int len_mess = sizeof(mess)/sizeof(int)/4;
  static int packet = 0;
  static int packpos = 0;
  static int framecounter = 0;

  int uart_send = 0;

  if (packet < len_mess) {
    if ((~uart_status & 1) && framecounter >= mess[packet*(LEN_PACKET + 1)]) {
      *uart_in = mess[(1 + packpos++) + packet*(LEN_PACKET + 1)];
      if (packpos == LEN_PACKET) {
        packet++;
        packpos = 0;
      }
      uart_send = 1;
      printf("sent: 0x%03X\n", *uart_in);
    }
  }

  if (uart_status & 2) {
    if (!print_strings)
      printf("recieved: %d\n", uart_out);
    else
    {
      stringbuff[string_idx++] = (char) uart_out;
      if (uart_out == 0 || string_idx == 256)
      {
        printf("%s", stringbuff);
        string_idx = 0;
      }
    }
  }

  framecounter++;
  return uart_send;
}

// void popMessage(int* outbuff, int* outlen) {
//   if (keyind > 0) {
//     *outlen = keymess[0];
//     for (int i = 0; i < *outlen; i++) {
//       outbuff[i] = keymess[i + 1];
//     }
//     for (int i = 1; i < MESSAGE_BUFF_LEN; i++) {
//       for (int j = 0; j < MESSAGE_MAX; j++) {
//         keymess[(i - 1)*MESSAGE_MAX + j] = keymess[i*MESSAGE_MAX + j];
//       }
//     }
//     keyind--;
//   }
// }

// int messageManagerDynamic(int messind, int uart_status, int* uart_in, int uart_out) {
//   static int messbuff[4];
//   static int messlen = 0;
//   static int messsubindex = 0;
//   static int prevMessNum = 0;
//   static int packpos = 0;
//   static int busy = 0;
//   int uart_send = 0;

//   if ((!busy) && messind > 0) {
//     popMessage(messbuff, &messlen);
//     messsubindex = 0;
//     busy = 1;
//   }

//   if (messsubindex < messlen) {
//     if (~uart_status & 1) {
//       *uart_in = messbuff[messsubindex++];
//       uart_send = 1;
//       printf("sent: 0x%02X\n", *uart_in);
//     }
//   } else busy = 0;

//   if (uart_status & 2) {
//     printf("recieved: %d\n", uart_out);
//   }

//   return uart_send;
// }

int uart(Veurones *tb, int tr, int send, int* rec) {
  // 31250 baud
  static int transmitTick = 0;
  static int recieveTick = 0;
  static int recieveState = 0;
  static int transmitState = 0;
  static int transmitting = 0;
  static int recieving = 0;
  int just_recieved = 0;
  int just_sent = 0;


  if (tr == 1){
    transmitting = 1;
  }

  if (transmitting){
    if (transmitTick++ == ACCUMULATOR_COMPARE){
      transmitTick = 0;

      if (transmitState == 0) {
        tb->RX = 0;
        transmitState++;
      } else if (transmitState == 9) {
        tb->RX = 1;
        transmitState = 0;
        transmitting = 0;
        just_sent = 1;
      } else {
        tb->RX = (send >> (transmitState - 1)) & 1;
        transmitState++;
      }
    }
  }


  if (!recieving && tb->TX == 0){
    recieving = 1;
    *rec = 0;
  }
  if (recieving){
    if (recieveTick++ == ACCUMULATOR_COMPARE){
      recieveTick = 0;
      if (recieveState < 9 && recieveState > 0){
        *rec |= (tb->TX == 1) << (recieveState - 1);
        recieveState++;
      }else if (recieveState == 9){
        recieveState = 0;
        recieving = 0;
        just_recieved = 1;
      }else{
        recieveState++;
      }
    }
  }

  return transmitting | (just_recieved << 1) | (just_sent << 2);
}
