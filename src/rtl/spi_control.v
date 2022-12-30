// ------------
// SPI CONTROL module
//
// PARAMETERS:
//             WIDTH - width one data packet
//             DEPTH - depth for FIFO, max amount of storage packets
// ------------
module spi_control
#(parameter WIDTH = 8,
  parameter DEPTH = 8)
(
 // SYSTEM SIGNALS:
 input                rst_n,        // global reset (async)
 input                clk,          // global clock

 // SIMPLE BUS INTERFACE
 input [31:0]         data_in,      // data from CPU
 input                status_wr,    // status register write enable
 input                data_wr,      // write enable for data
 input                data_rd,      // read data enable
 output [31:0]        data_out,     // received data to CPU
 
 // CONTROL INPUTS:
 input                tx_not_empty, // signs, that tx_buf contain data for next transmit
 input                rx_not_empty, // signs, that rx_buf contain received data

 // CONTROL OUTPUTS:
 output               wr_en,        // write enable (to transciever)
 output               read,         // read data from transciever (erase rx_buf)
 output [1:0]         mode,         // selected SPI mode for transaction
 output [2:0]         baud_sel,     // selected baud rate freq for transaction

 // TRANCEIVER INTERFACE
 input  [WIDTH - 1:0] rx_data,      // received data
 output [WIDTH - 1:0] tx_data       // transmitt data
 );
    
  // ------------
  // Internal wire's
  wire [WIDTH - 1:0]  fifo_tx_in;    // data to FIFO tx
  wire [WIDTH - 1:0]  fifo_tx_out;   // data from FIFO tx
  wire                fifo_tx_wr;    // write to FIFO tx
  wire                fifo_tx_rd;    // read from FIFO tx
  wire                fifo_tx_empty; // empty flag from FIFO tx
  
  wire [WIDTH - 1:0]  fifo_rx_in;    // data to FIFO rx
  wire [WIDTH - 1:0]  fifo_rx_out;   // data from FIFO rx
  wire                fifo_rx_wr;    // write to FIFO rx
  wire                fifo_rx_rd;    // read from FIFO rx
  wire                fifo_rx_empty; // empty flag from FIFO rx
  
  // ------------
  // Internal register's
  reg [         4:0]  status;  // status register
  reg                 tx_wr;   // write enable to tx_buf inside SPI transceiver
  reg                 rx_rd;   // read enable from rx_buf inside SPI transceiver

  // ------------
  // Outputs control wire
  assign wr_en    = tx_wr;
  assign read     = rx_rd;
  assign mode     = status[4:3];
  assign baud_sel = status[2:0];

  // ------------
  // MODULE IMPLEMENTATION
  // Transmit data FIFO
  fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) tx_fifo_inst 
    ( .rst_n    ( rst_n         ),
      .clk      ( clk           ),
      .data_in  ( fifo_tx_in    ),
      .data_out ( fifo_tx_out   ),
      .clear    ( 1'b0          ),
      .wr_en    ( fifo_tx_wr    ),
      .rd_en    ( fifo_tx_rd    ),
      .full     (               ),
      .empty    ( fifo_tx_empty ));

  assign fifo_tx_wr = data_wr;
  assign fifo_tx_rd = tx_wr && tx_not_empty;
  assign fifo_tx_in = data_in[WIDTH-1:0];
  assign tx_data    = fifo_tx_out;
  // ------------

  // Received data FIFO
  fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) rx_fifo_inst
    ( .rst_n    ( rst_n         ),
      .clk      ( clk           ),
      .data_in  ( fifo_rx_in    ),
      .data_out ( fifo_rx_out   ),
      .clear    ( 1'b0          ),
      .wr_en    ( fifo_rx_wr    ),
      .rd_en    ( fifo_rx_rd    ),
      .full     (               ),
      .empty    ( fifo_rx_empty ));  

  assign fifo_rx_wr = rx_rd && rx_not_empty;
  assign fifo_rx_rd = data_rd;
  assign fifo_rx_in = rx_data;
  assign data_out = { {(32-WIDTH){1'b0}}, fifo_rx_out };
  // ------------
  
  // ------------
  // STATUS REGISTER LOGIC
  always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
      status <= { 5{1'b0} };
    end else if ( status_wr ) begin
      status <= data_in[4:0];
    end
  end // always @ ( posedge clk or negedge rst_n )
  // ------------

  // ------------
  // READ ENABLE FROM TRANSCEIVER LOGIC
  always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
      rx_rd <= 1'b0;
    end else begin
      rx_rd <= rx_not_empty;
    end
  end // always @ ( posedge clk or negedge rst_n )
  // ------------
  
  // ------------
  // WRITE ENABLE TO TRANSCEIVER
  always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
      tx_wr <= 1'b0;
    end else begin
      tx_wr <= !(tx_not_empty || fifo_tx_empty);
    end
  end // always @ ( posedge clk or negedge rst_n )
  // ------------
  
endmodule // spi_control
// ------------   
