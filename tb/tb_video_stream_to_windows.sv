`timescale 1 ps / 1 ps
module tb_video_stream_to_window;

parameter int    PX_WIDTH      = 12;
parameter int    PX_PER_CLK    = 4;
parameter int    WIN_SIZE      = 3;
parameter int    MAX_LINE_SIZE = 1936;
parameter int    CLK_T         = 13468;
parameter int    RES_X         = 1936;
parameter int    TOTAL_X       = 2200;
parameter int    RES_Y         = 1096;
parameter int    TOTAL_Y       = 1125;
parameter int    PX_AMOUNT     = RES_X * RES_Y;
parameter string FRAME_PATH    = "../scripts/img.hex";

bit                                                                            clk;
bit                                                                            rst;
bit [PX_PER_CLK - 1 : 0][PX_WIDTH - 1 : 0]                                     px_data;
bit [PX_PER_CLK - 1 : 0]                                                       px_data_val;
bit                                                                            line_start_i;
bit                                                                            line_end_i;
bit                                                                            frame_start_i;
bit                                                                            frame_end_i;
bit [PX_PER_CLK - 1 : 0][WIN_SIZE - 1 : 0][WIN_SIZE - 1 : 0][PX_WIDTH - 1 : 0] win_data;
bit [PX_PER_CLK - 1 : 0]                                                       win_data_val;
bit                                                                            frame_start_o;
bit                                                                            frame_end_o;
bit                                                                            line_start_o;
bit                                                                            line_end_o;

bit [11 : 0] frame_rom [PX_AMOUNT - 1 : 0];
bit [RES_Y - 1 : 0][RES_X - 1 : 0][PX_WIDTH - 1 : 0] frame;

initial
  $readmemh( FRAME_PATH, frame_rom );

function automatic void remap_frame_rom ();

  for( int y = 0; y < RES_Y; y++ )
    for( int x = 0; x < RES_X; x++ )
      frame[y][x] = frame_rom[(y * x)];

endfunction

task automatic clk_gen();

  forever
    begin
      #( CLK_T / 2 );
      clk = !clk;
    end

endtask

task automatic apply_rst();

  @( posedge clk );
  rst <= 1'b1;
  @( posedge clk );
  rst <= 1'b0;

endtask

task automatic start_video_stream();

  int words_per_line = RES_X / PX_PER_CLK;
  int last_word_px   = RES_X % PX_PER_CLK;

  if( last_word_px > 0 )
    ADD_PX = 1;
  else
    ADD_PX = 0;

  for( int y = 0; y < TOTAL_Y; y++ )
    for( int x = 0; x < ( TOTAL_X / PX_PER_CLK ); x++ )
      begin
        @( posedge clk );
        if( y < RES_Y && x < ( words_per_line + ADD_PX ) )
          begin
            if( y == 0 && x == 0 )
              frame_start_i <= 1'b1;
            else
              frame_start_i <= 1'b0;
            if( x == words_per_line + ADD_PX - 1 )
              begin
                line_end_i <= 1'b1;
                if( ADD_PX )
                  px_data_val <= last_word_px;
                else
                  px_data_val <= '1;
              end
            else
              begin
                line_end_i  <= 1'b0;
                px_data_val <= '1;
              end
            if( y == ( RES_Y - 1 ) && x == ( words_per_line + ADD_PX - 1 ) )
              frame_end_i <= 1'b1;
            else
              frame_end_i <= 1'b0;
            if( x == 0 )
              line_start_i <= 1'b1;
            else
              line_start_i <= 1'b0;
            for( int i = 0; i < PX_PER_CLK; i++ )
              px_data[i] <= frame[y][x * PX_PER_CLK + i];
          end
        else
          begin
            px_data       <= '0;
            px_data_val   <= '0;
            line_start_i  <= 1'b0;
            line_end_i    <= 1'b0;
            frame_start_i <= 1'b0;
            frame_end_i   <= 1'b0;
          end
      end

endtask

video_stream_to_window #(
  .PX_WIDTH       ( PX_WIDTH      ),
  .PX_PER_CLK     ( PX_PER_CLK    ),
  .WIN_SIZE       ( WIN_SIZE      ),
  .MAX_LINE_SIZE  ( MAX_LINE_SIZE )
) DUT (
  .clk_i          ( clk           ),
  .rst_i          ( rst           ),
  .px_data_i      ( px_data       ),
  .px_data_val_i  ( px_data_val   ),
  .line_start_i   ( line_start_i  ),
  .line_end_i     ( line_end_i    ),
  .frame_start_i  ( frame_start_i ),
  .frame_end_i    ( frame_end_i   ),
  .win_data_o     ( win_data      ),
  .win_data_val_o ( win_data_val  ),
  .frame_start_o  ( frame_start_o ),
  .frame_end_o    ( frame_end_o   ),
  .line_start_o   ( line_start_o  ),
  .line_end_o     ( line_end_o    )
);

initial
  begin
    fork
      clk_gen();
    join_none
    apply_rst();
    remap_frame_rom();
    fork
      start_video_stream();
    join_none
    while( !frame_end_i )
      @( posedge clk );
    $stop();
  end

endmodule
