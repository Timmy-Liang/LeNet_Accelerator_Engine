# Testbench
lenet_tb.v
# SRAM behavior model
sram_model/SRAM_activation_1024x32b.v
sram_model/SRAM_weight_16384x32b.v
# Add your design here
../hdl/lenet.v
../hdl/conv1.v
../hdl/conv2.v
../hdl/conv3.v
../hdl/fc6.v
../hdl/fc7.v
#../hdl/relu_quan_bias.v
#../hdl/pureinnerproduct8_1.v
#../hdl/reluQuan.v
#../hdl/innerproduct8_2.v
#../hdl/innerproduct8_5.v
#../hdl/poolReluQuan.v
#../hdl/PoolReluQuan8_2.v

+access+r
