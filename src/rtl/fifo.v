// ------------
// FIRST INPUT - FIRST OUTPUT (FIFO)
//
// PARAMETERS:
//             WIDTH - width for one data packet
//             DEPTH - max amount of data packets for storage
// ------------
module fifo   
#(parameter WIDTH = 8,
  parameter DEPTH = 4)
(
 // SYSTEM SIGNALS
 input                rst_n,    // global reset (async)
 input                clk,      // global clock

 // DATA BUSES
 input  [WIDTH - 1:0] data_in,  // input data bus
 output [WIDTH - 1:0] data_out, // output data bus

 // CONTROL SIGNALS
 input                clear,    // clear all memory
 input                wr_en,    // write enable
 input                rd_en,    // read enable
 
 output               full,     // full FIFO flag
 output               empty     // empty FIFO flag
 );

  // ------------
  // Local parameters
  localparam POINT_WIDTH = $clog2(DEPTH);
    
  // ------------
  // Internal registers
  reg [WIDTH       - 1:0]   mem [DEPTH - 1:0]; // fifo memory
  reg [POINT_WIDTH - 1:0]   wr_point;          // write pointer
  reg [POINT_WIDTH - 1:0]   rd_point;          // read pointer
  reg                       over;              // over memory
  
  // ------------
  // MODULE IMPLEMENTATION

  // ------------
  // WRITE POINTER HANDLER
  always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0  ) begin
      wr_point <= { (POINT_WIDTH){1'b0} };
    end else if ( clear ) begin
      wr_point <= { (POINT_WIDTH){1'b0} };
    end else if ( wr_en ) begin
      wr_point <= wr_point + 1'b1;
    end
  end
  // ------------

  // ------------
  // READ POINTER HANDLER
  always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0  ) begin
      rd_point <= { (POINT_WIDTH){1'b0} };
    end else if ( clear ) begin
      rd_point <= { (POINT_WIDTH){1'b0} };
    end else if ( rd_en ) begin
      rd_point <= rd_point + 1'b1;
    end
  end
  // ------------

  // ------------
  // WRITE DATA IN FIFO
  always @ ( posedge clk ) begin
    if ( wr_en ) begin
      mem[ wr_point ] <= data_in;
    end
  end
  // ------------

  // ------------
  // READ DATA & STATUS
  assign data_out = mem[ rd_point ];
  assign empty    = ( wr_point == rd_point ) && !over;
  assign full     = ( wr_point == rd_point ) &&  over;

  // ------------
  // OVER MEMORY
  always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
      over <= 1'b0;
    end else if ( clear ) begin
      over <= 1'b0;
    end else if ( (wr_point == (DEPTH - 1)) && wr_en ) begin
      over <= 1'b1;
    end else if ( rd_en && !wr_en ) begin
      over <= 1'b0;
    end
  end // always @ ( posedge clk or negedge rst_n )
  // ------------
  
endmodule // fifo
// ------------
