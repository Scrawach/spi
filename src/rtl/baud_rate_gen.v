// ------------
// BAUD RATE GENERATOR for SPI Master module
//
// Create SPI clock, rise and fall pulses for data shifting
//
// Tout = (x + 2) * 2 * Tin.
//    Tout - output clock period (ns),
//    Tin  - input clock period (ns),
//    x    - code, that selected by SEL;
//
// Table for selected X :
//  ------------------------------------------------------
// | SEL: | 000 | 001 | 010 | 011 | 100 | 101 | 110 | 111 |
//  ------------------------------------------------------
// | X  : |   1 |   8 |  16 |  24 |  32 |  40 |  48 |  63 |
//  ------------------------------------------------------
//
// For example, when Tin = 20ns (it's 50MHz), then:
//              if SEL = 3'b000 (x =  1), Tout = (1 + 2) * 2 * 20 = 120ns (~8,3(3) MHz)
//              if SEL = 3'b001 (x =  8), Tout =  400ns (~2,5    MHz),
//              if SEL = 3'b010 (x = 16), Tout =  720ns (~1,3(8) MHz),
//              if SEL = 3'b011 (x = 24), Tout = 1040ns (~0,961  MHz),
//              if SEL = 3'b100 (x = 32), Tout = 1360ns (~0,735  MHz),
//              if SEL = 3'b101 (x = 40), Tout = 1680ns (~0,595  MHz),
//              if SEL = 3'b110 (x = 48), Tout = 2000ns (~0,500  MHz),
//              if SEL = 3'b111 (x = 63), Tout = 2600ns (~0,385  MHz),
//
// ------------
module baud_rate_gen
(
 // SYSTEM SIGNALS
 input       rst_n,   // global reset
 input       clk,     // global clock

 // CONTROL INPUTS
 input       en,      // enable for strobe generate
 input [1:0] mode,    // SPI transceiver mode selector
 input [2:0] sel,     // baud rate selector
 input       sclk_en, // enable for generate SCLK by strobe

 // CONTROL OUTPUTS
 output      strobe,  // every change SCLK pulse
 output      rise,    // rise front SCLK
 output      fall,    // fall fron SCLK
 
 // SPI INTERFACE
 output      sclk     // SCLK
 );

  // ------------
  // Internal wires
  wire       cpol;    // clock polarity (selected SPI mode)
  wire       cpha;    // clock phase    (selected SPI mode)
  wire       ref_clk; // reference (gold) clock for generate SCLK

  // ------------
  // Internal registers
  reg [5:0] cnt, cnt_nxt; // simple counter
  reg [5:0] sel_cnt;      // selected counter number (for freq)
  reg       clk_en;       // strobe for generate reference clock
  reg       ref_cpha_0;   // reference 50% duty cycle clock by selected strobes (pha = 0)
  reg       ref_cpha_1;   // reference 50% duty cycle clock by selected strobes (pha = 1)
  
  // ------------
  // MODULE IMPLEMENTATION
  // ------------

  // ------------
  // Useful assigns
  assign cpol = mode[1];
  assign cpha = mode[0];

  // ------------
  // COUNTER FOR CLOCK DIVIDE
  always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
      cnt <= 6'h0;
    end else begin
      cnt <= cnt_nxt;
    end
  end // always @ ( posedge clk or negedge rst_n ) 

  always @ ( * ) begin
    if ( clk_en      ) begin
      cnt_nxt = 6'h0;
    end else if ( en ) begin
      cnt_nxt = cnt + 3'b1;
    end else begin
      cnt_nxt = 6'h0;
    end
  end // always @ ( * )
  // ------------

  // ------------
  // SELECT FREQ AND CREATE STROBE (clk_en)
  always @ ( * ) begin
    case ( sel )
      3'b000  : sel_cnt = 6'd1; 
      3'b001  : sel_cnt = 6'd8; 
      3'b010  : sel_cnt = 6'd16;
      3'b011  : sel_cnt = 6'd24;
      3'b100  : sel_cnt = 6'd32;
      3'b101  : sel_cnt = 6'd40;
      3'b110  : sel_cnt = 6'd48;
      3'b111  : sel_cnt = 6'd63;
      default : sel_cnt = 6'd0;
    endcase // case ( sel )
  end // always @ ( * )

  always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
      clk_en <= 1'b0;
    end else begin
      clk_en <= (cnt == sel_cnt);
    end
  end // always @ ( posedge clk or negedge rst_n )

  assign strobe = clk_en;
  // ------------

  // ------------
  // REFERENCE CLOCK GENERATE FOR EVERY PHASE MODE
  always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
      ref_cpha_0 <= 1'b0;
    end else if ( sclk_en && strobe ) begin
      ref_cpha_0 <= !ref_cpha_0;
    end
  end // always @ ( posedge clk or negedge rst_n )

  always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
      ref_cpha_1 <= 1'b0;
    end else if ( strobe ) begin
      ref_cpha_1 <= ref_cpha_0;
    end
  end // always @ ( posedge clk or negedge rst_n )
  // ------------

  // ------------
  // SPI CLOCK GENERATE
  assign ref_clk = cpha ? ref_cpha_1 : ref_cpha_0;
  assign sclk    = cpol ? ref_clk : !ref_clk;
  assign fall    =  ref_cpha_0 && strobe;
  assign rise    = !ref_cpha_0 && strobe;
  // ------------

endmodule // baud_rate_gen
// ------------   
