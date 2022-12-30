// ------------
// SPI Top Level with countrol unit
//
// Description: Take data from CPU and send it to SPI
//
// The following registers are defined:
// |-----------|------------------------------------------------------|
// |  Address  | Description                                          |
// |-----------|------------------------------------------------------|
// |   0x40    | Status register with configuration (WRITE/READ)      |
// |   0x44    | Write data values to FIFO from data bus (WRITE)      |
// |   0x48    | Read received data from FIFO (READ)                  |
// |-----------|------------------------------------------------------|
//
//
// Status register defined:
// |-------------------------------------------------------------------------------|
// | 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
// |-------------------------------------------------------------------------------|
// |                        RESERVED                      |   mode  |  baud rate   |
// |-------------------------------------------------------------------------------|
//
// mode         - select SPI mode, mode = {cpol, cpha}
// baud rate    - select baud rate for generate SCLK
//
// PARAMETERS:
//             WIDTH      - bus width, that transmit\received
//             FIFO_DEPTH - depth for tx & rx FIFO
// -------------
module spi_core
#(parameter      WIDTH = 8,
  parameter FIFO_DEPTH = 8)
(
 // SYSTEM INPUT
 input         rst_n,        // global reset (async)
 input         clk,          // global clock

 // SIMPLE BUS INTERFACE
 input [31:0]  data_in,      // data from CPU
 input         status_wr,    // status register write enable  
 input         data_wr,      // write enable
 input         data_rd,      // read data
 output [31:0] data_out,     // data to CPU

 // CONTROL OUTPUT
 output        req,          // signs, that current task is done

 // SPI INTERFACE
 input         spi_data_in,  // SDI ( MISO )
 output        spi_data_out, // SDO ( MOSI )
 output        spi_clk,      // SCLK
 output        cs_n          // CS, chip select (slave select)
 );

  // ------------
  // Internal wires
  wire [WIDTH - 1:0] tx_data;
  wire [WIDTH - 1:0] rx_data;
  wire [        2:0] baud_sel;
  wire [        1:0] mode;
  
  wire               tx_not_empty;
  wire               rx_not_empty;
  wire               wr_en;
  wire               read;
  
  // ------------
  // MODULE IMPLEMENTATION
  // SPU CONTROL UNIT
  spi_control #(.WIDTH(WIDTH), .DEPTH(FIFO_DEPTH)) control_inst 
    ( .rst_n        ( rst_n        ),
      .clk          ( clk          ),
      .data_in      ( data_in      ),
      .status_wr    ( status_wr    ),
      .data_wr      ( data_wr      ),
      .data_rd      ( data_rd      ),
      .data_out     ( data_out     ),
      .tx_not_empty ( tx_not_empty ),
      .rx_not_empty ( rx_not_empty ),
      .wr_en        ( wr_en        ),
      .read         ( read         ),
      .mode         ( mode         ),
      .baud_sel     ( baud_sel     ),
      .tx_data      ( tx_data      ),
      .rx_data      ( rx_data      ));

  // SPI MASTER TRANSCEIVER
  spi_transceiver #(.WIDTH(WIDTH)) trans_inst
    ( .rst_n        ( rst_n        ),
      .clk          ( clk          ),
      .tx_data      ( tx_data      ),
      .rx_data      ( rx_data      ),
      .wr_en        ( wr_en        ),
      .read         ( read         ),
      .mode         ( mode         ),
      .baud_sel     ( baud_sel     ),
      .tx_not_empty ( tx_not_empty ),
      .rx_not_empty ( rx_not_empty ),
      .request      ( req          ),
      .spi_data_in  ( spi_data_in  ),
      .spi_clk      ( spi_clk      ),
      .spi_data_out ( spi_data_out ),
      .cs_n         ( cs_n         ));
  // ------------

endmodule // spi_top
// ------------
