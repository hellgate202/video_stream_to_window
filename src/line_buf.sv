module line_buf #(
  parameter int PIXEL_WIDTH    = 12,
  parameter int PIXELS_PER_CLK = 4.
  parameter int LINE_BUF_LIMIT = 1936
)(
  input                                                clk_i,
  input                                                rst_i,
  input [PIXELS_PER_CLK - 1 : 0][PIXEL_WIDTH - 1 : 0]  px_data_i,
  input [PIXELS_PER_CLK - 1 : 0]                       px_data_val_i,
  input                                                line_start_i,
  input                                                line_end_i,
  input                                                frame_start_i,
  input                                                frame_end_i,
  input                                                pop_line_i,
  output [PIXELS_PER_CLK - 1 : 0][PIXEL_WIDTH - 1 : 0] px_data_o,
  output [PIXELS_PER_CLK - 1 : 0]                      px_data_val_o,
  output                                               line_start_o,
  output                                               line_end_o,
  output                                               frame_start_o,
  output                                               frame_end_o,
  output                                               empty_o
);

localparam int DATA_WIDTH = PIXEL_WIDTH * PIXELS_PER_CLK;
localparam int ADDR_WIDTH = $clog2( MAX_LINE_WIDTH / PIXELS_PER_CLK + 1 );

logic [ADDR_WIDTH - 1 : 0]     wr_ptr;
logic [ADDR_WIDTH - 1 : 0]     line_size;
logic [ADDR_WIDTH - 1 : 0]     rd_ptr;
logic                          read_in_progress;
logic [PIXELS_PER_CLK - 1 : 0] line_end_valid;
logic                          push_data;
logic                          empty;
logic                          was_sof;
logic                          was_eof;
logic                          line_start;
logic                          line_end;
logic                          frame_start;
logic                          frame_end;
logic [PIXELS_PER_CLK - 1 : 0] px_data_val;

assign push_data = |px_data_val_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    wr_ptr <= '0;
  else
    if( push_data )
      if( line_end_i )
        wr_ptr <= '0;
      else
        wr_ptr <= wr_ptr + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    line_size <= '0;
  else
    if( push_data && line_end_i )
      line_size <= wr_ptr + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    empty <= 1'b1;
  else
    if( push_data )
      if( line_end_i )
        empty <= 1'b0;
      else
        empty <= 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_in_progress <= 1'b0;
  else
    if( rd_ptr == ( line_size - 1'b1 ) )
      read_in_progress <= 1'b0;
    else
      if( pop_line_i && !empty )
        read_in_progress <= 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rd_ptr <= '0;
  else
    if( pop_line_i && !empty )
      rd_ptr <= '0;
    else
      if( read_in_progress )
        rd_ptr <= rd_ptr + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    line_end_valid <= '0;
  else
    if( push_data && line_end_i )
      line_end_valid <= px_data_val_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    px_data_val <= '0;
  else
    if( read_in_progress )
      if( rd_ptr == ( line_size - 1'b1 ) )
        px_data_val <= line_end_valid;
      else
        px_data_val <= '1;
    else
      px_data_val <= '0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    line_start <= 1'b0;
  else
    if( pop_line_i && empty )
      line_start <= 1'b1;
    else
      line_start <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    line_end <= 1'b0;
  else
    if( read_in_progress && rd_ptr == ( line_size - 1'b1 ) )
      line_end <= 1'b1;
    else
      line_end <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    was_sof <= 1'b0;
  else
    if( push_data && line_start_i )
      if( frame_start_i )
        was_sof <= 1'b1;
      else
        was_sof <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    was_eof <= 1'b0;
  else
    if( push_data && line_end_i )
      if( frame_end_i )
        was_eof <= 1'b1;
      else
        was_eof <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    frame_start <= 1'b0;
  else
    if( pop_line_i && !empty && was_sof )
      frame_start <= 1'b1;
    else
      frame_start <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    frame_end <= 1'b0;
  else
    if( read_in_progress && rd_ptr == ( line_size - 1'b1 ) && was_eof )
      frame_end <= 1'b1;
    else
      frame_end <= 1'b0;

dual_port_ram #(
  .DATA_WIDTH ( DATA_WIDTH ),
  .ADDR_WIDTH ( ADDR_WIDTH )
) buf_ram (
  .wr_clk_i   ( clk_i      ),
  .wr_addr_i  ( wr_ptr     ),
  .wr_data_i  ( px_data_i  ),
  .wr_i       ( push_data  ),
  .rd_clk_i   ( clk_i      ),
  .rd_data_o  ( px_data_o  ),
  .rd_i       ( 1'b1       )
);

assign empty_o       = empty;
assign line_start_o  = line_start;
assign line_end_o    = line_end;
assign frame_start_o = frame_start;
assign frame_end_o   = frame_end;
assign px_data_val_o = px_data_val;

endmodule
