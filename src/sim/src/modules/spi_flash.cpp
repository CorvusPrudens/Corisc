#include <cstdio>
#include "spi_flash.h"

Flash::Flash() 
{
    Reset();

    snoozy = false;
    writeEnabled = false;
    debug = false;

    memset(memory, 0, sizeof(uint8_t) * memSize_p);
}

void Flash::Tick(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce)
{
    bool clocked = false;
    if (prevClk != clk)
    {
        clocked = true;
        prevClk = clk;
    }

    if (ce == 0 && clocked) {

        // NOTE -- this doesn't account for various 
        // spi modes since the clock MUST be low when 
        // ce is asserted
        if (clk == 1) posedgeClocks++;
        else negedgeClocks++;

    }

    (this->*methods[state])(sdi, sdo, clk, ce, clocked);

    *sdo = sdo_intern;
}

Flash::State Flash::MatchCommand()
{
    for (int i = 0; i < sizeof(commands); i++)
    {
        if (command == commands[i]) {
            if (debug)
                printf("Command: %s\n", trans[i]);
            return (State) i;
        }
    }

    return State::ERROR;
}

void Flash::Reset()
{
    prevClk = 0;
    posedgeClocks = 0;
    negedgeClocks = 0;
    command = 0;
    address = 0;
    addressOffset = 0;
    bitPosGeneral = 7;
    bitPosAddress = 23;
    sdo_intern = 0;

    memset(buffer, -1, sizeof(uint32_t) * pageSize_p);
    state = State::IDLE;
}

// The first clock of resulting commands is always negative
void Flash::Idle(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked)
{
    if (ce == 0)
    {
        if (clocked)
        {
            if (clk == 1)
            {
                command |= (sdi & 1) << bitPosGeneral--;

                if (bitPosGeneral == -1) 
                {
                    bitPosGeneral = 7;
                    state = MatchCommand();

                    if (snoozy && !(state == State::IDLE || state == State::WAKE))
                    {
                        state = State::ERROR;
                    }
                }
            }
        }
    }
    else
    {
        Reset();
    }
}

void Flash::Write(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked)
{
    if (ce == 0)
    {
        if (clocked)
        {
            if (!writeEnabled)
            {
                state = State::ERROR;
            }
            if (clk == 1)
            {
                if (bitPosAddress == -1)
                {
                    if (address % pageSize_p != 0)
                    {
                        addressOffset = address % pageSize_p;
                        address -= addressOffset;
                    }
                    
                    // Just assuming the address is valid for now
                    int input = (sdi & 1) << bitPosGeneral--;
                    if (buffer[addressOffset] == -1)
                        buffer[addressOffset] = 0;
                    buffer[addressOffset] |= input;
                    if (bitPosGeneral == -1)
                    {
                        // this will naturally wrap
                        addressOffset++;
                        bitPosGeneral = 7;
                    }
                }
                else
                {
                    address |= (sdi & 1) << bitPosAddress--;
                    if (bitPosAddress == -1 && debug)
                        printf("Address: 0x%X | %d\n", address, address % pageSize_p);
                }
            }
        }
    }
    else
    {
        // Writing must end on a byte boundary
        if (bitPosGeneral == 7)
        {
            for (size_t i = address; i < address + pageSize_p; i++)
            {
                int index = i % 256;
                // only write addresses that were actually written to
                if (buffer[index] != -1) memory[i] = (uint8_t) buffer[index] & 255;
            }
        }
        writeEnabled = false;
        Reset();
    }
}

void Flash::Read(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked)
{
    if (ce == 0)
    {
        if (clocked)
        {
            if (clk == 0)
            {
                if (bitPosAddress == -1)
                {
                    if (address % pageSize_p != 0)
                    {
                        addressOffset = address % pageSize_p;
                        address -= addressOffset;
                    }
                    
                    // Just assuming the address is valid for now
                    sdo_intern = (uint8_t) (memory[address + addressOffset] >> bitPosGeneral--) & 1;
                    if (bitPosGeneral == -1)
                    {
                        // this will naturally wrap
                        addressOffset++;
                        bitPosGeneral = 7;
                    }
                }
            }
            else
            {
                if (bitPosAddress != -1)
                {
                    address |= (sdi & 1) << bitPosAddress--;
                    if (bitPosAddress == -1 && debug)
                        printf("Address: 0x%X | %d\n", address, address % pageSize_p);
                }
            }
        }
    }
    else
    {
        Reset();
    }
}

void Flash::Erase(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked)
{
    if (ce == 0)
    {
        if (!writeEnabled)
        {
            state = State::ERROR;
        }
        if (clocked)
        {
            if (clk == 1)
            {
                address |= (sdi & 1) << bitPosAddress;
            }
            else
            {
                if (bitPosAddress-- == 0)
                {
                    // ERASE LOGIC
                    writeEnabled = false;

                    if (address % blockSize_p != 0)
                    {
                        // err
                    }
                    else
                    {
                        for (int i = address; i < address + blockSize_p; i++)
                        {
                            memory[i] = 1;
                        }
                    }

                    Reset();
                }
            }
        }
    }
    else
    {
        Reset();
    }
}

void Flash::Status(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked)
{
    if (ce == 0)
    {
        if (clocked)
        {
            if (clk == 0) {
                // we'll just always assume we're not busy
                int32_t reg = 0 | (((int) writeEnabled) << 1);
                sdo_intern = 1 & (reg >> bitPosGeneral);
            }
            // This ~could~ allow invalid operations like starting a new
            // command without deasserting ce, but I don't feel like
            // fixing it right now
            else {
                if (bitPosGeneral-- == 0)
                {
                    Reset();
                }
            }
        }
    }
    else
    {
        Reset();
    }
}

void Flash::WriteEnable(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked)
{
    if (ce == 0)
    {
        if (clocked && clk == 1) state = State::ERROR;
    }
    else
    {
        writeEnabled = true;
        Reset();
    }
}

void Flash::Sleep(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked)
{
    if (ce == 0)
    {
        if (clocked && clk == 1) state = State::ERROR;
    }
    else
    {
        snoozy = true;
        Reset();
    }
}

void Flash::Wake(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked)
{
    if (ce == 0)
    {
        if (clocked && clk == 1) state = State::ERROR;
    }
    else
    {
        snoozy = false;
        Reset();
    }
}

void Flash::Error(uint8_t sdi, uint8_t* sdo, uint8_t clk, uint8_t ce, bool clocked)
{
    if (ce)
    {
        Reset();
    }
}

void Flash::RandomFill(size_t startAddr, size_t length)
{
    for (int i = startAddr; i < startAddr + length; i++)
    {
        uint8_t random = std::rand() & 255;
        memory[i] = random;
    }
}

uint8_t crc_test[] = {
    51, 214, 155, 209, 206, 168, 61, 64, 101, 113, 87, 143, 147, 136, 69, 80, 
    10, 62, 188, 53, 36, 29, 74, 26, 113, 180, 34, 76, 166, 248, 136, 20, 
    201, 143, 126, 13, 109, 65, 216, 228, 203, 48, 81, 99, 2, 78, 131, 148, 
    211, 125, 26, 129, 203, 82, 116, 245, 123, 61, 213, 186, 36, 238, 47, 219, 
    6, 5, 123, 38, 30, 64, 99, 231, 150, 241, 129, 27, 248, 147, 79, 157, 
    174, 237, 9, 191, 196, 221, 86, 183, 127, 116, 109, 153, 27, 134, 31, 26, 
    186, 202, 183, 189, 176, 37, 215, 189, 235, 194, 190, 175, 58, 176, 66, 68, 
    6, 235, 188, 29, 188, 230, 86, 4, 76, 125, 183, 210, 130, 107, 164, 194, 
    83, 117, 136, 68, 85, 107, 36, 57, 249, 66, 206, 109, 247, 36, 169, 78, 
    180, 226, 116, 33, 23, 197, 71, 41, 158, 70, 120, 44, 108, 75, 148, 233, 
    164, 154, 95, 12, 102, 7, 208, 126, 18, 61, 138, 45, 36, 191, 119, 226, 
    46, 193, 245, 120, 107, 225, 216, 32, 141, 178, 149, 180, 67, 207, 126, 58, 
    146, 82, 24, 120, 206, 63, 206, 163, 167, 115, 16, 150, 116, 191, 61, 203, 
    227, 185, 23, 28, 40, 49, 185, 199, 41, 163, 210, 46, 150, 153, 1, 230, 
    112, 240, 20, 203, 195, 252, 187, 85, 144, 224, 209, 138, 96, 113, 25, 88, 
    142, 141, 243, 175, 86, 1, 136, 222, 23, 145, 134, 153,

    0x08, 0x0E, 0x0E, 0xEA
};

// message crc: 0x080E0EEA