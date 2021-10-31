#include <cstring>

#ifndef TARGET
#define TARGET top
#endif

#ifndef TRACE_FILE
#define TRACE_FILE "trace.vcd"
#endif

#ifndef CLOCK_COUNT
#define CLOCK_COUNT 30000
#endif

#ifndef NUM_FRAMES
#define NUM_FRAMES 1
#endif

#ifndef PROG_BIN
#define PROG_BIN "rv32i.bin"
#endif

#define SCALE 5
#define WIDTH 128
#define HEIGHT 64
#define XOFFSET 8
#define YOFFSET 8
#define CLOCKS_PER_FRAME 238636.3

#include <GL/glew.h>
#include <GLFW/glfw3.h>

#include "Vrv32i.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "uart.h"
#include "spi_flash.h"
#include "sram16.h"
#include "utils.h"

Sram16 sram;
Flash flash;

int main(int argc, char** argv) 
{

  ///////////////////////////////////////////////////////////////
  // GL stuff
  ///////////////////////////////////////////////////////////////
  uint32_t glBuffer[WIDTH*HEIGHT] = {0xFF000000};

  const GLchar* vertexSource = R"glsl(
      #version 150 core
      in vec2 position;
      in vec2 texcoord;
      out vec2 Texcoord;
      void main()
      {
          Texcoord = texcoord;
          gl_Position = vec4(position, 0.0, 1.0);
      }
  )glsl";
  const GLchar* fragmentSource = R"glsl(
      #version 150 core
      in vec2 Texcoord;
      out vec4 outColor;
      uniform sampler2D tex;
      void main()
      {
          outColor = texture(tex, Texcoord);
      }
  )glsl";

  glfwInit();

  #ifdef __APPLE__
  glfwWindowHint (GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint (GLFW_CONTEXT_VERSION_MINOR, 2);
  glfwWindowHint (GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
  glfwWindowHint (GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
  GLFWwindow* window = glfwCreateWindow(1440, 720, "CPU", nullptr, nullptr); // Windowed
  #else
  glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);
  GLFWwindow* window = glfwCreateWindow(1920, 960, "CPU", nullptr, nullptr);
  #endif

  glfwSetKeyCallback(window, key_callback);

  glfwSwapInterval(1);
  glfwMakeContextCurrent(window);
  glewExperimental = GL_TRUE;
  glewInit();

  // Create Vertex Array Object
  GLuint vao;
  glGenVertexArrays(1, &vao);
  glBindVertexArray(vao);

  // Create a Vertex Buffer Object and copy the vertex data to it
  GLuint vbo;
  glGenBuffers(1, &vbo);

  GLfloat vertices[] = {
  //  Position      Color             Texcoords
      -1.0f,  1.0f,  0.0f, 0.0f, // Top-left
       1.0f,  1.0f,  1.0f, 0.0f, // Top-right
       1.0f, -1.0f,  1.0f, 1.0f, // Bottom-right
      -1.0f, -1.0f,  0.0f, 1.0f  // Bottom-left
  };

  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

  // Create an element array
  GLuint ebo;
  glGenBuffers(1, &ebo);

  GLuint elements[] = {
      0, 1, 2,
      2, 3, 0
  };

  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(elements), elements, GL_STATIC_DRAW);

  // Create and compile the vertex shader
  GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vertexShader, 1, &vertexSource, NULL);
  glCompileShader(vertexShader);

  // Create and compile the fragment shader
  GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fragmentShader, 1, &fragmentSource, NULL);
  glCompileShader(fragmentShader);

  // Link the vertex and fragment shader into a shader program
  GLuint shaderProgram = glCreateProgram();
  glAttachShader(shaderProgram, vertexShader);
  glAttachShader(shaderProgram, fragmentShader);
  glBindFragDataLocation(shaderProgram, 0, "outColor");
  glLinkProgram(shaderProgram);
  glUseProgram(shaderProgram);

  // Specify the layout of the vertex data
  GLint posAttrib = glGetAttribLocation(shaderProgram, "position");
  glEnableVertexAttribArray(posAttrib);
  glVertexAttribPointer(posAttrib, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), 0);

  // GLint colAttrib = glGetAttribLocation(shaderProgram, "color");
  // glEnableVertexAttribArray(colAttrib);
  // glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));

  GLint texAttrib = glGetAttribLocation(shaderProgram, "texcoord");
  glEnableVertexAttribArray(texAttrib);
  glVertexAttribPointer(texAttrib, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));

  // Load texture
  GLuint tex;
  glGenTextures(1, &tex);
  glBindTexture(GL_TEXTURE_2D, tex);

  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, WIDTH, HEIGHT, 0, GL_RGBA, GL_UNSIGNED_BYTE, glBuffer);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

  ///////////////////////////////////////////////////////////////
  // GL stuff end
  ///////////////////////////////////////////////////////////////

  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);

  Vrv32i *tb = new Vrv32i;
  VerilatedVcdC* tfp = new VerilatedVcdC;

  unsigned logicStep = 0;

  #ifdef TRACE
    tb->trace(tfp, 99);
    tfp->open(TRACE_FILE);
  #endif

  size_t clock_count = CLOCK_COUNT;
  if (argc >= 2) {
    clock_count = atoi(argv[1]);
  }

  // UART vars
  int sendword = 0;
  int status = 0;
  int go = 0;
  int out = 0;
  tb->RX = 1;
  uint8_t displaybuff[WIDTH*(HEIGHT/8)] = {0};
  tick(tb, tfp, sram, flash, displaybuff, ++logicStep);

  // Bootloader verification
  #ifdef BOOTLOADER
    size_t start_addr = 0x300000;
    size_t write_len = 256 * 256;
    flash.RandomFill(start_addr, write_len);

    for (size_t i = 0; i < clock_count; i++)
    {
      go = messageManagerStatic(status, &sendword, out, false);
      status = uart(tb, go, sendword, &out);
      tick(tb, tfp, sram, flash, ++logicStep);
    }

    bool success = true;
    uint8_t* ram_test = (uint8_t*) sram.memory;
    for (size_t i = start_addr; i < start_addr + write_len / 2 + 16; i++)
    {
      if (*ram_test++ != flash[i])
        success = false;
    }
    if (success)
      printf("Bootloader test passed!\n");
    else
      printf("Bootloader test failed :c\n");
  #else

    LoadProgram(PROG_BIN, (uint8_t*) sram.memory);

    for (int j = 0; j < NUM_FRAMES; ) {
      for (int i = 0; i < CLOCKS_PER_FRAME; i++) {
        go = messageManagerStatic(status, &sendword, out, false);
        status = uart(tb, go, sendword, &out);
        tick(tb, tfp, sram, flash, displaybuff, ++logicStep);
        if (tb->FRAME_SYNC) {
          updatePixels(displaybuff, glBuffer, WIDTH, HEIGHT);
          writeFrame(displaybuff, "./build/frames.bin", WIDTH, HEIGHT);
          j++;
          currentFrame++;
        }
      }
      glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, WIDTH, HEIGHT, GL_RGBA, GL_UNSIGNED_BYTE, glBuffer);
      glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

      glfwSwapBuffers(window);
      glfwPollEvents();
      if (endExecution) {
        break;
      }
    }

  #endif

  tb->final();
  delete tb;
  delete tfp;
}