# readfile
								   
set HDL_DIR "./hdl"
set SOURCE_FILE "$HDL_DIR/conv1.v 
    $HDL_DIR/conv2.v 
    $HDL_DIR/conv3.v 
    $HDL_DIR/fc6.v $HDL_DIR/fc7.v 
    $HDL_DIR/innerproduct8_2.v 
    $HDL_DIR/innerproduct8_5.v 
    $HDL_DIR/lenet.v 
    $HDL_DIR/PoolReluQuan8_2.v 
    $HDL_DIR/poolReluQuan.v 
    $HDL_DIR/pureinnerproduct8_1.v 
    $HDL_DIR/relu_quan_bias.v 
    $HDL_DIR/reluQuan.v"

set RPT_FILE "spyglass.rpt"
read_file -type verilog $SOURCE_FILE


#goal setup (lint_rtl)
current_goal lint/lint_rtl -alltop
run_goal
capture $RPT_FILE {write_report moresimple}

#goal setup (lint_turbo_rtl)
current_goal lint/lint_turbo_rtl -alltop
run_goal
capture -append $RPT_FILE {write_report moresimple}

#goal setup (lint_functional_rtl)
current_goal lint/lint_functional_rtl -alltop
run_goal
capture -append $RPT_FILE {write_report moresimple}

#goal setup (lint_abstract)
current_goal lint/lint_abstract -alltop
run_goal
capture -append $RPT_FILE {write_report moresimple}

#goal setup (adv_lint_struct)
current_goal adv_lint/adv_lint_struct -alltop
run_goal
capture -append $RPT_FILE {write_report moresimple}

#goal setup (adv_lint_verify)
current_goal adv_lint/adv_lint_verify -alltop
run_goal
capture -append $RPT_FILE {write_report moresimple}
