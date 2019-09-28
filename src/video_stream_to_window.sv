module video_stream_to_window #(
  parameter int PX_WIDTH      = 12,
  parameter int PX_PER_CLK    = 4,
  parameter int WIN_SIZE      = 3,
  parameter int MAX_LINE_SIZE = 4112
)(
  input                                                                                   clk_i,
  input                                                                                   rst_i,
  input        [PX_PER_CLK - 1 : 0][PX_WIDTH - 1 : 0]                                     px_data_i,
  input        [PX_PER_CLK - 1 : 0]                                                       px_data_val_i,
  input                                                                                   line_start_i,
  input                                                                                   line_end_i,
  input                                                                                   frame_start_i,
  input                                                                                   frame_end_i,
  output logic [PX_PER_CLK - 1 : 0][WIN_SIZE - 1 : 0][WIN_SIZE - 1 : 0][PX_WIDTH - 1 : 0] win_data_o,
  output logic [PX_PER_CLK - 1 : 0]                                                       win_data_val_o,
  output                                                                                  frame_start_o,
  output                                                                                  frame_end_o,
  output                                                                                  line_start_o,
  output                                                                                  line_end_o
);

localparam int DATA_WIDTH    = PX_WIDTH * PX_PER_CLK;
localparam int ACT_BUF_SIZE  = PX_PER_CLK + WIN_SIZE - 1;
localparam int REAL_BUF_SIZE = ( ACT_BUF_SIZE % PX_PER_CLK ) == 0 ? ACT_BUF_SIZE :
                                                                  ( ACT_BUF_SIZE / PX_PER_CLK + 1 ) * PX_PER_CLK;
localparam int SHIFT_STAGES  = REAL_BUF_SIZE / PX_PER_CLK;

logic                                                                                push_data;
logic                                                                                push_data_d1;
logic [PX_PER_CLK - 1 : 0]                                                           active_wr_buf;
logic [WIN_SIZE : 0][PX_PER_CLK - 1 : 0]                                             px_data_val_masked;
logic [PX_PER_CLK - 1 : 0]                                                           active_rd_buf;
logic [WIN_SIZE : 0]                                                                 read_buf;
logic [PX_PER_CLK - 1 : 0][WIN_SIZE : 0][PX_WIDTH - 1 : 0]                           data_from_buf;
logic [PX_PER_CLK - 1 : 0][WIN_SIZE : 0][PX_WIDTH - 1 : 0]                           shifted_data_from_buf;
logic [PX_PER_CLK - 1 : 0][WIN_SIZE - 1 : 0][PX_WIDTH - 1 : 0]                       data_to_shift_reg;
logic [PX_PER_CLK - 1 : 0][WIN_SIZE : 0]                                             data_val_from_buf;
logic [PX_PER_CLK - 1 : 0][WIN_SIZE : 0]                                             shifted_data_val_from_buf;
logic [PX_PER_CLK - 1 : 0][WIN_SIZE - 1 : 0]                                         data_val_to_shift_reg;
logic [WIN_SIZE : 0]                                                                 line_start_from_buf;
logic [WIN_SIZE : 0]                                                                 shifted_line_start_from_buf;
logic [WIN_SIZE - 1: 0]                                                              line_start_to_shift_reg;
logic [WIN_SIZE : 0]                                                                 line_end_from_buf;
logic [WIN_SIZE : 0]                                                                 shifted_line_end_from_buf;
logic [WIN_SIZE - 1: 0]                                                              line_end_to_shift_reg;
logic [WIN_SIZE : 0]                                                                 frame_start_from_buf;
logic [WIN_SIZE : 0]                                                                 shifted_frame_start_from_buf;
logic [WIN_SIZE - 1: 0]                                                              frame_start_to_shift_reg;
logic [WIN_SIZE : 0]                                                                 frame_end_from_buf;
logic [WIN_SIZE : 0]                                                                 shifted_frame_end_from_buf;
logic [WIN_SIZE - 1: 0]                                                              frame_end_to_shift_reg;
logic [WIN_SIZE : 0]                                                                 unread_from_buf;
logic [WIN_SIZE : 0]                                                                 shifted_unread_from_buf;
logic [WIN_SIZE - 1: 0]                                                              unread_to_shift_reg;
logic [SHIFT_STAGES - 1 : 0][PX_PER_CLK - 1 : 0][WIN_SIZE - 1 : 0][PX_WIDTH - 1 : 0] data_shift_reg;
logic [SHIFT_STAGES - 1 : 0][PX_PER_CLK - 1 : 0][WIN_SIZE - 1 : 0]                   data_val_shift_reg;
logic [SHIFT_STAGES - 1 : 0][WIN_SIZE - 1 : 0]                                       line_start_shift_reg;
logic [SHIFT_STAGES - 1 : 0][WIN_SIZE - 1 : 0]                                       line_end_shift_reg;
logic [SHIFT_STAGES - 1 : 0][WIN_SIZE - 1 : 0]                                       frame_start_shift_reg;
logic [SHIFT_STAGES - 1 : 0][WIN_SIZE - 1 : 0]                                       frame_end_shift_reg;
logic [SHIFT_STAGES - 1 : 0][WIN_SIZE - 1 : 0]                                       unread_shift_reg;
logic                                                                                shift;
logic                                                                                read_done;
logic [REAL_BUF_SIZE - 1 : 0][WIN_SIZE - 1 : 0][PX_WIDTH - 1 : 0]                    data_shift_reg_unpacked;
logic [ACT_BUF_SIZE - 1 : 0][WIN_SIZE - 1 : 0][PX_WIDTH - 1 : 0]                     act_data_reg;
logic [REAL_BUF_SIZE - 1 : 0][WIN_SIZE - 1 : 0]                                      data_val_shift_reg_unpacked;
logic [ACT_BUF_SIZE - 1 : 0][WIN_SIZE - 1 : 0]                                       act_data_val_reg;


assign push_data  = |px_data_val_i;
assign read_done  = line_end_to_shift_reg[WIN_SIZE - 1];
assign read_ready = unread_to_shift_reg[WIN_SIZE - 1];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    push_data_d1 <= 1'b0;
  else
    push_data_d1 <= push_data;

assign shift = push_data || push_data_d1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    active_wr_buf <= 'b1;
  else
    if( push_data && line_end_i )
      active_wr_buf <= active_wr_buf <<< 1;

always_comb
  for( int i = 0; i <= WIN_SIZE; i++ )
    if( active_wr_buf[i] )
      px_data_val_masked = px_data_val_i;
    else
      px_data_val_masked = '0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    active_rd_buf <= { 1'b0, { (WIN_SIZE - 1 ){ 1'b1 } } };
  else
    if( read_done )
      active_rd_buf <= active_rd_buf <<< 1;

always_comb
  for( int i = 0; i <= WIN_SIZE; i++ )
    if( active_rd_buf[i] )
      read_buf = read_ready;
    else
      read_buf = 1'b0;
      
genvar i;

generate
  for( i = 0; i <= WIN_SIZE; i++ )
    begin : line_buffers
      line_buf #(
        .PX_WIDTH      ( PX_WIDTH                                 ),
        .PX_PER_CLK    ( PX_PER_CLK                               ),
        .MAX_LINE_SIZE ( MAX_LINE_SIZE                            )
      ) line_buf (
        .clk_i         ( clk_i                                    ),
        .rst_i         ( rst_i                                    ),
        .px_data_i     ( px_data_i                                ),
        .px_data_val_i ( px_data_val_masked[i]                    ),
        .line_start_i  ( line_start_i                             ),
        .line_end_i    ( line_end_i                               ),
        .frame_start_i ( frame_start_i                            ),
        .frame_end_i   ( frame_end_i                              ),
        .pop_line      ( read_buf[i]                              ),
        .px_data_o     ( data_from_buf[PX_PER_CLK - 1 : 0][i]     ),
        .px_data_val_o ( data_val_from_buf[PX_PER_CLK - 1 : 0][i] ),
        .line_start_o  ( line_start_from_buf[i]                   ),
        .line_end_o    ( line_end_from_buf[i]                     ),
        .frame_start_o ( frame_start_from_buf[i]                  ),
        .frame_end_o   ( frame_end_from_buf[i]                    ),
        .empty_o       (                                          ),
        .unread_o      ( unread_from_buf[i]                       )
      );
    end
endgenerate

always_comb
  begin
    int inact_pos = 0;
    for( int i = 0; i <= WIN_SIZE; i++ )
      if( active_rd_buf[i] == 1'b0 )
        inact_pos = i;
    if( inact_pos == WIN_SIZE )
      begin
        shifted_data_from_buf        = data_from_buf;
        shifted_data_val_from_buf    = data_val_from_buf;
        shifted_line_start_from_buf  = line_start_from_buf;
        shifted_line_end_from_buf    = line_end_from_buf;
        shifted_frame_start_from_buf = frame_start_from_buf;
        shifted_frame_end_from_buf   = frame_end_from_buf;
        shifted_unread_from_buf      = unread_from_buf;
      end
    else
      begin
        shifted_data_from_buf        = data_from_buf        <<< ( inact_pos + 1 );
        shifted_data_val_from_buf    = data_val_from_buf    <<< ( inact_pos + 1 );
        shifted_line_start_from_buf  = line_start_from_buf  <<< ( inact_pos + 1 );
        shifted_line_end_from_buf    = line_end_from_buf    <<< ( inact_pos + 1 );
        shifted_frame_start_from_buf = frame_start_from_buf <<< ( inact_pos + 1 );
        shifted_frame_end_from_buf   = frame_end_from_buf   <<< ( inact_pos + 1 );
        shifted_unread_from_buf      = unread_from_buf      <<< ( inact_pos + 1 );
      end
  end

assign data_to_shift_reg        = shifted_data_from_buf[WIN_SIZE - 1 : 0];
assign data_val_to_shift_reg    = shifted_data_val_from_buf[WIN_SIZE - 1 : 0];
assign line_start_to_shift_reg  = shifted_line_start_from_buf[WIN_SIZE - 1 : 0];
assign line_end_to_shift_reg    = shifted_line_end_from_buf[WIN_SIZE - 1 : 0];
assign frame_start_to_shift_reg = shifted_frame_start_from_buf[WIN_SIZE - 1 : 0];
assign frame_end_to_shift_reg   = shifted_frame_end_from_buf[WIN_SIZE - 1 : 0];
assign unread_to_shift_reg      = shifted_unread_from_buf[WIN_SIZE - 1 : 0];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    begin
      data_shift_reg        <= '0;
      data_val_shift_reg    <= '0;
      line_start_shift_reg  <= '0;
      line_end_shift_reg    <= '0;
      frame_start_shift_reg <= '0;
      frame_end_shift_reg   <= '0;
      unread_shift_reg      <= '0;
    end
  else
    if( shift )
      begin
        data_shift_reg[0]        <= data_to_shift_reg;
        data_val_shift_reg[0]    <= data_val_to_shift_reg;
        line_start_shift_reg[0]  <= line_start_to_shift_reg;
        line_end_shift_reg[0]    <= line_end_to_shift_reg;
        frame_start_shift_reg[0] <= frame_start_to_shift_reg;
        frame_end_shift_reg[0]   <= frame_end_to_shift_reg;
        unread_shift_reg[0]      <= unread_to_shift_reg;
        for( int i = 1; i < SHIFT_STAGES; i++ )
          begin
            data_shift_reg[i]        <= data_shift_reg[i - 1];
            data_val_shift_reg[i]    <= data_val_shift_reg[i - 1];
            line_start_shift_reg[i]  <= line_start_shift_reg[i - 1];
            line_end_shift_reg[i]    <= line_end_shift_reg[i - 1];
            frame_start_shift_reg[i] <= frame_start_shift_reg[i - 1];
            frame_end_shift_reg[i]   <= frame_end_shift_reg[i - 1];
            unread_shift_reg[i]      <= unread_shift_reg[i - 1];
          end
      end

always_comb
  for( int i = 0; i < SHIFT_STAGES; i++ )
    begin
      data_shift_reg_unpacked[PX_PER_CLK * ( i + 1 ) - 1 -: PX_PER_CLK]     = data_shift_reg[i];
      data_val_shift_reg_unpacked[PX_PER_CLK * ( i + 1 ) - 1 -: PX_PER_CLK] = data_val_shift_reg[i];
    end

assign act_data_reg     = data_shift_reg_unpacked[ACT_BUF_SIZE - 1 : 0];
assign act_data_val_reg = data_val_shift_reg_unpacked[ACT_BUF_SIZE - 1 : 0];

always_comb
  for( int i = 0; i < PX_PER_CLK; i++ )
    begin
      win_data_o[i]     = act_data_reg[WIN_SIZE + i - 1 -: WIN_SIZE];
      win_data_val_o[i] = act_data_val_reg[WIN_SIZE + i - 1 -: WIN_SIZE][WIN_SIZE - 1];
    end

assign line_start_o  = line_start_shift_reg[0];
assign line_end_o    = ACT_BUF_SIZE == REAL_BUF_SIZE ? line_end_shift_reg[0] : line_end_shift_reg[1];
assign frame_start_o = frame_start_shift_reg[0];
assign frame_end_o   = ACT_BUF_SIZE == REAL_BUF_SIZE ? frame_end_shift_reg[0] : frame_end_shift_reg[1]; 

endmodule
