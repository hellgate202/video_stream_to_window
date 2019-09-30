vlib work
vlog +define+SIM -sv -f ./files
vopt +acc tb_video_stream_to_window -o tb_video_stream_to_window_opt
vsim tb_video_stream_to_window_opt
do wave.do
run -all
