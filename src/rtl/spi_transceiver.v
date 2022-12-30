// ------------
// SPI MASTER TRANSCEIVER module
//
// Description: SPI (Serial Peripheral Interface) Master
//
// Send and receive bytes while tx_buf has data.
//
// Can select SPI mode (cpol / cpha). And output SCLK freq.
// About SPI mode: https://en.wikipedia.org/wiki/Serial_Peripheral_Interface#Mode_numbers
//
// Parameters: WIDTH       - transaction width (std is 8 bit's)
// ------------
module spi_transceiver
#(parameter WIDTH = 8)
(
 // SYSTEM SIGNALS:
 input                rst_n,        // global reset (async)
 input                clk,          // global clock

 // MAIN DATA BUSES:
 input  [WIDTH - 1:0] tx_data,      // transmit data
 output [WIDTH - 1:0] rx_data,      // received data

 // CONTROL INPUTS:
 input                wr_en,        // write enable (to tx_buf, start transaction)
 input                read,         // read data from rx_buf (reset rx_not_empty pulse)
 input  [        1:0] mode,         // select SPI mode for transaction
 input  [        2:0] baud_sel,     // select baud rate freq for transaction
  
 // CONTROL OUTPUTS:
 output               tx_not_empty, // signs, that tx_buf contain data for next transmit
 output               rx_not_empty, // signs, that rx_buf contain received data
 output               request,      // signs, that all current transaction is done 
 
 // SPI INTERFACE:
 input                spi_data_in,  // SDI ( MOSI )
 output               spi_clk,      // SCLK
 output               spi_data_out, // SDO ( MISO )
 output               cs_n          // Chip select
 );
 
  // ------------
  // Localparam's
  localparam        // MAIN FSM:
    IDLE = 4'b0001, // IDLE, nothing to do
    LOAD = 4'b0010, // LOAD data from buffer to transceiver register
    WORK = 4'b0100, // WORK, transmit and receive data
    SAVE = 4'b1000; // SAVE received data to buffer

  localparam
    BIT_CNT_WIDTH = $clog2(WIDTH); // WIDTH for bit counter
    
  // ------------
  // Internal wires
  wire                rise_sclk;  // rise front SCLK
  wire                fall_sclk;  // fall front SCLK
  wire                trans_done; // done one transaction
  wire                strobe;     // clk enable
  wire                spi_en;     // baud rate generator enable (for SCLK)
    
  // ------------
  // Internal registers
  reg [                3:0] state, state_nxt;         // control fsm
  reg [        WIDTH - 1:0] tx_buf;                   // transmit data buffer
  reg [        WIDTH - 1:0] rx_buf;                   // received data buffer
  reg [        WIDTH - 1:0] trans_buf, trans_buf_nxt; // transaction buffer (shift-register)
  reg [BIT_CNT_WIDTH - 1:0] bit_cnt, bit_cnt_nxt;     // transaction's bit counter
  reg                       busy, busy_nxt;           // busy flag signs, that it's working now
  reg                       txne, txne_nxt;           // tx_buf not empty reg's
  reg                       rxne, rxne_nxt;           // rx_buf not empty reg's
  reg                       done, done_nxt;           // flag done transaction
  // ------------
  // MODULE IMPLEMENTATION
  // ------------
        
  // BAUD RATE GENERATOR
  baud_rate_gen brg_inst 
    ( .rst_n   ( rst_n     ),
      .clk     ( clk       ),
      .en      ( busy      ),
      .mode    ( mode      ),
      .sel     ( baud_sel  ),
      .sclk_en ( spi_en    ),
      // OUTPUTS:
      .strobe  ( strobe    ),
      .rise    ( rise_sclk ),
      .fall    ( fall_sclk ),
      .sclk    ( spi_clk   ));

  assign spi_en = ( state != IDLE );
  // ------------
  
  // ------------
  // TRANSMIT BUFFER (TX)
  always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0  ) begin
      tx_buf <= { (WIDTH){1'b0} };
    end else if ( wr_en ) begin
      tx_buf <= tx_data;
    end
  end
  // ------------

  // ------------
  // RECEIVE BUFFER (RX)
  always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
      rx_buf <= 1'b0;
    end else if ( trans_done ) begin
      rx_buf <= { trans_buf[WIDTH - 2:0], spi_data_in };
    end
  end

  assign rx_data = rx_buf;
  // ------------

  // ------------
  // TRANSACTION BUFFER LOGIC (SHIFT-REGISTER)
  always @ ( * ) begin
    case ( state )
      IDLE    : trans_buf_nxt = strobe    ?                       { (WIDTH){1'b0} } : trans_buf;
      LOAD    : trans_buf_nxt = rise_sclk ?                                  tx_buf : trans_buf;
      default : trans_buf_nxt = rise_sclk ? { trans_buf[WIDTH - 2:0], spi_data_in } : trans_buf;
    endcase // case ( state )
  end // always @ ( * )

  assign spi_data_out = trans_buf[WIDTH - 1];
  // ------------

  // ------------
  // TX & RX BUFFER NOT EMPTY FLAG LOGIC
  always @ ( * ) begin
    case ( state )
      LOAD    : txne_nxt = rise_sclk ? 1'b0 : txne;
      default : txne_nxt = wr_en     ? 1'b1 : txne;
    endcase // case ( state )
  end // always @ ( * )

  always @ ( * ) begin
    case ( state )
      SAVE    : rxne_nxt = 1'b1;
      default : rxne_nxt = read ? 1'b0 : rxne;
    endcase // case ( state )
  end // always @ ( * )

  assign tx_not_empty = txne;
  assign rx_not_empty = rxne;
  // ------------

  // ------------
  // BUSY FLAG LOGIC
  always @ ( * ) begin
    case ( state )
      IDLE    : busy_nxt = rise_sclk ? 1'b0 : busy;
      LOAD    : busy_nxt = 1'b1;
      default : busy_nxt = busy;
    endcase // case ( state )
  end // always @ ( * )

  assign cs_n = !busy;
  // ------------

  // ------------
  // DONE TRANSACTION LOGIC
  always @ ( * ) begin
    case ( state )
      IDLE    : done_nxt = rise_sclk ? busy : 1'b0;
      default : done_nxt = 1'b0;
    endcase // case ( state )
  end // always @ ( * )

  assign request = done;
  // ------------
  
  // ------------
  // TRANSACTION BIT COUNTER
  always @ ( * ) begin
    case ( state )
      //                      fall_sclk ? bit_cnt + 1'b1 : bit_cnt
      WORK    : bit_cnt_nxt = fall_sclk ? bit_cnt + { {(BIT_CNT_WIDTH-1){1'b0}}, 1'b1 } : bit_cnt;
      default : bit_cnt_nxt = { (BIT_CNT_WIDTH){1'b0} };
    endcase // case ( state )
  end // always @ ( * )

  assign trans_done = fall_sclk && ( bit_cnt == 3'h7 );
  // ------------

  // ------------
  // MAIN FSM IMPLEMENTATION
  always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
      state     <= IDLE;
      bit_cnt   <= { (BIT_CNT_WIDTH){1'b0} };
      trans_buf <= { (WIDTH){1'b0}};
      txne      <= 1'b0;
      rxne      <= 1'b0;
      busy      <= 1'b0;
      done      <= 1'b0;
    end else begin
      state     <= state_nxt;
      bit_cnt   <= bit_cnt_nxt;
      trans_buf <= trans_buf_nxt;
      txne      <= txne_nxt;
      rxne      <= rxne_nxt;
      busy      <= busy_nxt;
      done      <= done_nxt;
    end
  end // always @ ( posedge clk or negedge rst_n )

  // STATES CHANGE CONDITION
  always @ ( * ) begin
    case ( state )
      IDLE    : state_nxt = wr_en      ? LOAD : IDLE;
      LOAD    : state_nxt = rise_sclk  ? WORK : LOAD;
      WORK    : state_nxt = trans_done ? SAVE : WORK;
      SAVE    : state_nxt = txne       ? LOAD : IDLE;
      default : state_nxt = IDLE;
    endcase // case ( state )
  end // always @ ( * )
  // ------------
  
endmodule // spi
// ------------
