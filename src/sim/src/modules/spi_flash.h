#ifndef SPI_FLASH_H
#define SPI_FLASH_H

#include <string.h>
#include <cstdlib>
#include <cstdint>

#define flashSleep_p  0xB9
#define flashWake_p   0xA9
#define flashRead_p   0x03
#define flashWen_p    0x06
#define flashErase_p  0x20 // 4-kb sector
#define flashWrite_p  0x02
#define flashStatus_p 0x05

#define blockSize_p 4096
#define pageSize_p  256
#define memSize_p 8388608

// TODO -- there's a bug where reading
// can cause aligment issues (i.e. unexpected zeros)
class Flash {

    public:

        Flash();
        ~Flash() {}

        enum State {
            IDLE = 0,
            WRITE,
            READ,
            ERASE,
            STATUS,
            WRITE_ENABLE,
            SLEEP,
            WAKE,
            ERROR,
        };

        const char* trans[9] = {
            "idle",
            "write",
            "read",
            "erase",
            "status",
            "write enable",
            "sleep",
            "wake",
            "error",
        };

        const uint8_t commands[8] = {
            0xFF,
            flashWrite_p,
            flashRead_p,
            flashErase_p,
            flashStatus_p,
            flashWen_p,
            flashSleep_p,
            flashWake_p
        };

        void Tick(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce);

        void RandomFill(size_t startAddr, size_t length);

        uint8_t& operator[](size_t index) { return memory[index]; }

    private:

        State MatchCommand();

        void Reset();

        void Idle(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked);

        void Write(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked);

        void Read(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked);

        void Erase(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked);

        void Status(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked);

        void WriteEnable(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked);

        void Sleep(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked);

        void Wake(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked);

        void Error(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked);

        void  (Flash::*methods[9])(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked) = {
            &Flash::Idle,
            &Flash::Write,
            &Flash::Read,
            &Flash::Erase,
            &Flash::Status,
            &Flash::WriteEnable,
            &Flash::Sleep,
            &Flash::Wake,
            &Flash::Error,
        };

        uint8_t memory[memSize_p];
        int buffer[pageSize_p];

        State state;
        uint8_t prevClk;

        size_t posedgeClocks;
        size_t negedgeClocks;

        uint8_t command;
        uint32_t address;
        uint8_t addressOffset;

        int bitPosGeneral;
        int bitPosAddress;

        bool snoozy;
        bool writeEnabled;
        bool debug;

        uint8_t sdo_intern;
};

extern uint8_t crc_test[];

#endif // SPI_FLASH_H