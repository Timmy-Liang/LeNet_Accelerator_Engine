module conv2(
    // Weight sram, dual port
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg finish,

    input wire [31:0] scale,
    output reg [ 3:0] weight_wea0,
    output reg [15:0] weight_addr0,
    input wire [31:0] weight_rdata0,
    output reg [ 3:0] weight_wea1,
    output reg [15:0] weight_addr1,
    input wire [31:0] weight_rdata1,

    // Activation sram, dual port
    output reg [ 3:0] act_wea0,
    output reg [15:0] act_addr0,
    output reg [31:0] act_wdata0,
    input wire [31:0] act_rdata0,
    output reg [ 3:0] act_wea1,
    output reg [15:0] act_addr1,
    output reg [31:0] act_wdata1,
    input wire [31:0] act_rdata1
);

    reg [3:0] state;
    reg [3:0] next_state;
    
    parameter [3:0] Pre=4'd0;
    parameter [3:0] Outchannel=4'd1;
    parameter [3:0] Inchannel=4'd6;
    parameter [3:0] LoadWeight=4'd2;
    parameter [3:0] LoadAct=4'd3;
    parameter [3:0] Comp=4'd4;
    parameter [3:0] PoolingQuan=4'd5;


    parameter [3:0] Finish=4'd9;
    parameter [3:0] Wait0=4'd10;
    parameter [3:0] Wait1=4'd11;
    parameter [3:0] Wait2=4'd12;
    parameter [3:0] Wait3=4'd13;
    parameter [3:0] Wait4=4'd14;
    parameter [3:0] Wait5=4'd15;
    parameter [3:0] Waitend0=4'd7;
    parameter [3:0] Waitend1=4'd8;


    reg [31:0]activation0;
    reg [31:0]activation1;
    reg [39:0]wt_row0;
    reg [39:0]wt_row1;
    reg [39:0]wt_row2;
    reg [39:0]wt_row3;
    reg [39:0]wt_row4;
    wire signed [31:0]comp_res[4:0][3:0];
    innerproduct8_5 inpro8_5(
        .act0(activation0),
        .act1(activation1),
        .wt_row0(wt_row0),
        .wt_row1(wt_row1),
        .wt_row2(wt_row2),
        .wt_row3(wt_row3),
        .wt_row4(wt_row4),
        .out_00(comp_res[0][0]),
        .out_01(comp_res[0][1]),
        .out_02(comp_res[0][2]),
        .out_03(comp_res[0][3]),    
        .out_10(comp_res[1][0]),
        .out_11(comp_res[1][1]),
        .out_12(comp_res[1][2]),
        .out_13(comp_res[1][3]),
        .out_20(comp_res[2][0]),
        .out_21(comp_res[2][1]),
        .out_22(comp_res[2][2]),
        .out_23(comp_res[2][3]),
        .out_30(comp_res[3][0]),
        .out_31(comp_res[3][1]),
        .out_32(comp_res[3][2]),
        .out_33(comp_res[3][3]),
        .out_40(comp_res[4][0]),
        .out_41(comp_res[4][1]),
        .out_42(comp_res[4][2]),
        .out_43(comp_res[4][3])
    );
    reg [31:0] prq_in[1:0][15:0];
    wire [31:0] quanout0;
    wire [31:0] quanout1;
    poolReluQuan28_7 prq(
        .scale (scale),
        .in0_0 (prq_in[0][0 ]),
        .in0_1 (prq_in[0][1 ]),
        .in0_2 (prq_in[0][2 ]),
        .in0_3 (prq_in[0][3 ]),
        .in0_4 (prq_in[0][4 ]),
        .in0_5 (prq_in[0][5 ]),
        .in0_6 (prq_in[0][6 ]),
        .in0_7 (prq_in[0][7 ]),
        .in0_8 (prq_in[0][8 ]),
        .in0_9 (prq_in[0][9 ]),
        .in0_10(prq_in[0][10]),
        .in0_11(prq_in[0][11]),
        .in0_12(prq_in[0][12]),
        .in0_13(prq_in[0][13]),
        .in0_14(prq_in[0][14]),
        .in0_15(prq_in[0][15]),
        .in1_0 (prq_in[1][0 ]),
        .in1_1 (prq_in[1][1 ]),
        .in1_2 (prq_in[1][2 ]),
        .in1_3 (prq_in[1][3 ]),
        .in1_4 (prq_in[1][4 ]),
        .in1_5 (prq_in[1][5 ]),
        .in1_6 (prq_in[1][6 ]),
        .in1_7 (prq_in[1][7 ]),
        .in1_8 (prq_in[1][8 ]),
        .in1_9 (prq_in[1][9 ]),
        .in1_10(prq_in[1][10]),
        .in1_11(prq_in[1][11]),
        .in1_12(prq_in[1][12]),
        .in1_13(prq_in[1][13]),
        .in1_14(prq_in[1][14]),
        .in1_15(prq_in[1][15]),
        .act0(quanout0),
        .act1(quanout1)
    );

    reg signed[ 7:0]weights2D[4:0][4:0];
    
//output channel
    reg [7:0]out_channel;
    reg [7:0]next_out_channel;
    
    always @(posedge clk) begin
        if(!rst_n)begin
            out_channel <= 0;
        end
        else begin
            out_channel <= next_out_channel;
        end
    end
    always @(*) begin
        if(state==Outchannel)begin
            next_out_channel=out_channel + 1;
        end
        else begin
            next_out_channel = out_channel;
        end
    end
    //input channel
    reg [7:0]in_channel;
    reg [7:0]next_in_channel;
    always @(posedge clk) begin
        if(!rst_n)begin
            in_channel <= 0;
        end
        else begin
            in_channel <= next_in_channel;
        end
    end
    always @(*) begin
        if(state==Inchannel)begin
            if(in_channel==5)begin
                next_in_channel=0;
            end
            else begin
                next_in_channel=in_channel + 1;
            end
        end
        else begin
            next_in_channel = in_channel;
        end
    end

    //row weight count
    reg [3:0]row_weight_cnt;
    reg [3:0]next_row_weight_cnt;
    always@(posedge clk) begin
        if(!rst_n) begin
            row_weight_cnt <= 4'd0;
        end
        else begin
            row_weight_cnt <= next_row_weight_cnt;
        end
    end
    always@(*)begin
        if (state==LoadWeight)begin
            next_row_weight_cnt =row_weight_cnt+1;
        end  
        else begin
            next_row_weight_cnt = 0;
        end
    end
//loading weight
    reg [3:0]loading_row_weight;
    reg [3:0]next_loading_row_weight;
    always@(posedge clk) begin
        if(!rst_n) begin
            loading_row_weight <= 4'd0;
        end
        else begin
            loading_row_weight <= next_loading_row_weight;
        end
    end
    always@(*)begin
        if (state==LoadWeight && row_weight_cnt>=3)begin
            if(loading_row_weight==4)next_loading_row_weight=4;
            else next_loading_row_weight =loading_row_weight+1;
        end  
        else begin
            next_loading_row_weight = 0;
        end
    end
    //save weight to array
    reg [39:0]next_save_weight;
    always@(*)begin
        if (state==LoadWeight )begin
            next_save_weight = {weight_rdata1[7:0] , weight_rdata0};
        end  
        else begin
            next_save_weight = 0;
        end
    end

    integer i;
    integer j;
    always@(posedge clk) begin
        if(!rst_n) begin
            for (i=0;i<5;i=i+1)begin
                for (j=0;j<5;j=j+1)begin
                    weights2D[i][j]<=0;
                end
            end
        end
        else begin
            if(state==LoadWeight && row_weight_cnt>=3)begin
                weights2D[loading_row_weight][0] <= next_save_weight[ 7: 0];
                weights2D[loading_row_weight][1] <= next_save_weight[15: 8];
                weights2D[loading_row_weight][2] <= next_save_weight[23:16];
                weights2D[loading_row_weight][3] <= next_save_weight[31:24];
                weights2D[loading_row_weight][4] <= next_save_weight[39:32];
            end
            else begin
                weights2D[loading_row_weight][0] <= weights2D[loading_row_weight][0];
                weights2D[loading_row_weight][1] <= weights2D[loading_row_weight][1];
                weights2D[loading_row_weight][2] <= weights2D[loading_row_weight][2];
                weights2D[loading_row_weight][3] <= weights2D[loading_row_weight][3];
                weights2D[loading_row_weight][4] <= weights2D[loading_row_weight][4];
            end
            
        end
    end
    
     //id of to-load activation 
    reg [7:0]act_cnt;
    reg [7:0]next_act_cnt;
    always@(posedge clk)begin
        if(!rst_n) begin
            act_cnt<=8'd0;
        end
        else begin 
            act_cnt <= next_act_cnt;
        end
    end
    always @(*)begin
        if (state==LoadAct||state==Wait0||state==Wait1||state==Comp)begin
                if(act_cnt==16'd8)begin //0,2,4,...18,20,then 21,23,25...39,41,then 42,44...
                    next_act_cnt = 0; 
                end
                else next_act_cnt = act_cnt+16'd4;
            end
        else begin
            next_act_cnt = 0;
        end
    end
    //row act
    reg [7:0]row_act_cnt;
    reg [7:0]next_row_act_cnt;
    always@(posedge clk)begin
        if(!rst_n) begin
            row_act_cnt<=8'd0;
        end
        else begin 
            row_act_cnt <= next_row_act_cnt;
        end
    end
    always @(*)begin
        if (state==LoadAct||state==Wait0||state==Wait1||state==Comp)begin
                if(act_cnt==16'd8)begin //0,2,4,...18,20,then 21,23,25...39,41,then 42,44...
                    if(row_act_cnt==16'd13)begin
                        next_row_act_cnt=0;
                    end
                    else begin
                        next_row_act_cnt = row_act_cnt+16'd1; 
                    end
                end
                else next_row_act_cnt = row_act_cnt;
        end
        else begin
            next_row_act_cnt = 0;
        end
    end
    //computing activation
    reg [7:0]cpact_col;
    reg [7:0]next_cpact_col;
    always@(posedge clk)begin
        if(!rst_n) begin
            cpact_col<=8'd0;
        end
        else begin 
            cpact_col <= next_cpact_col;
        end
    end
    always @(*)begin
        if (state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
                if(cpact_col==8'd8)begin //0,2,4,...18,20,then 21,23,25...39,41,then 42,44...
                    next_cpact_col = 0; 
                end
                else next_cpact_col = cpact_col+8'd4;
            end
        else begin
            next_cpact_col = 0;
        end
    end
    //row of cp act
    reg [7:0]cpact_row;
    reg [7:0]next_cpact_row;
    always@(posedge clk)begin
        if(!rst_n) begin
            cpact_row<=8'd0;
        end
        else begin 
            cpact_row <= next_cpact_row;
        end
    end
    always @(*)begin
        if (state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
                if(cpact_col==8'd8)begin //0,2,4,...18,20,then 21,23,25...39,41,then 42,44...
                    if(cpact_row==8'd13)begin
                        next_cpact_row=0;
                    end
                    else begin
                        next_cpact_row = cpact_row+8'd1;
                    end
                end
                else begin
                    next_cpact_row = cpact_row;
                end 
            end
        else begin
            next_cpact_row = 0;
        end
    end


    //save the psum
    //output array for a channel
    reg signed [31:0] out_act[9:0][9:0];
    reg signed [31:0] next_out_psum[4:0][3:0]; 
    //integer i,j;
    always@(posedge clk)begin
        if(!rst_n) begin
            for (i=0;i<10;i=i+1)begin
                for(j=0;j<10;j=j+1)begin
                    out_act[i][j]<=0;
                end
            end
        end
        else begin 
            if(state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
                case(cpact_row)
                //debug todo: the boundary of those "6" byte long
                    8'd0:begin
                        if(cpact_col<8)begin 
                            for (i=0;i<1;i=i+1)begin
                                for(j=0;j<4;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                        else begin
                            for (i=0;i<1;i=i+1)begin
                                for(j=0;j<2;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                        
                    end
                    8'd1:begin
                        if(cpact_col<8)begin 
                            for (i=0;i<2;i=i+1)begin
                                for(j=0;j<4;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                        else begin
                            for (i=0;i<2;i=i+1)begin
                                for(j=0;j<2;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                    end
                    8'd2:begin
                        if(cpact_col<8)begin 
                            for (i=0;i<3;i=i+1)begin
                                for(j=0;j<4;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                        else begin
                            for (i=0;i<3;i=i+1)begin
                                for(j=0;j<2;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                    end
                    8'd3:begin
                        if(cpact_col<8)begin 
                            for (i=0;i<4;i=i+1)begin
                                for(j=0;j<4;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                        else begin
                            for (i=0;i<4;i=i+1)begin
                                for(j=0;j<2;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                    end
                    8'd10:begin
                        if(cpact_col<8)begin 
                            for (i=1;i<5;i=i+1)begin
                                for(j=0;j<4;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                        else begin
                            for (i=1;i<5;i=i+1)begin
                                for(j=0;j<2;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                    end
                    8'd11:begin
                        if(cpact_col<8)begin 
                            for (i=2;i<5;i=i+1)begin
                                for(j=0;j<4;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                        else begin
                            for (i=2;i<5;i=i+1)begin
                                for(j=0;j<2;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                    end
                    8'd12:begin
                        if(cpact_col<8)begin 
                            for (i=3;i<5;i=i+1)begin
                                for(j=0;j<4;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                        else begin
                            for (i=3;i<5;i=i+1)begin
                                for(j=0;j<2;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                    end
                    8'd13:begin
                        if(cpact_col<8)begin 
                            for (i=4;i<5;i=i+1)begin
                                for(j=0;j<4;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                        else begin
                            for (i=4;i<5;i=i+1)begin
                                for(j=0;j<2;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                    end
                    default:begin
                        if(cpact_col<8)begin 
                            for (i=0;i<5;i=i+1)begin
                                for(j=0;j<4;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                        else begin
                            for (i=0;i<5;i=i+1)begin
                                for(j=0;j<2;j=j+1)begin
                                    out_act[cpact_row-i][cpact_col+j] <= next_out_psum[i][j];
                                end
                            end
                        end
                    end
                endcase
            end
            else begin
                //debug
                if(state==Outchannel)begin
                    for (i=0;i<10;i=i+1)begin
                        for(j=0;j<10;j=j+1)begin
                            out_act[i][j] <= 0;
                        end
                    end
                end
                else begin
                    for (i=0;i<10;i=i+1)begin
                        for(j=0;j<10;j=j+1)begin
                            out_act[i][j] <= out_act[i][j];
                        end
                    end
                end
                
            end
        end
        
    end
    //combinational saving and adding the psum 
    always @(*)begin
        if(state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
            case(cpact_row)
                8'd0:begin
                    if(cpact_col<8)begin
                        for (i=0;i<1;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                        for (i=1;i<5;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                    end
                    else begin
                        for (i=0;i<1;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                        for (i=1;i<5;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                        for (i=0;i<5;i=i+1)begin
                            for(j=2;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                    end
                    
                end
                8'd1:begin
                    if(cpact_col<8)begin
                        for (i=0;i<2;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                        for (i=2;i<5;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                        
                    end
                    else begin
                        for (i=0;i<2;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                        for (i=2;i<5;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                        for (i=0;i<5;i=i+1)begin
                            for(j=2;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                    end
                end
                8'd2:begin
                    if(cpact_col<8)begin
                        for (i=0;i<3;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                        for (i=3;i<5;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                    end
                    else begin
                        for (i=0;i<3;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                        for (i=3;i<5;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                        for (i=0;i<5;i=i+1)begin
                            for(j=2;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                    end
                end
                8'd3:begin
                    if(cpact_col<8)begin
                        for (i=0;i<4;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                        for (i=4;i<5;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                    end
                    else begin
                        for (i=0;i<4;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                        for (i=4;i<5;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                        for (i=0;i<5;i=i+1)begin
                            for(j=2;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                    end
                end
                8'd10:begin
                    if(cpact_col<8)begin
                        for (i=0;i<1;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                        for (i=1;i<5;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                    end
                    else begin
                        for (i=0;i<1;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                        for (i=1;i<5;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                        for (i=0;i<5;i=i+1)begin
                            for(j=2;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                    end
                end
                8'd11:begin
                    if(cpact_col<8)begin
                        for (i=0;i<2;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                        for (i=2;i<5;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                    end
                    else begin
                        for (i=0;i<2;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                        for (i=2;i<5;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                        for (i=0;i<5;i=i+1)begin
                            for(j=2;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                    end
                end
                8'd12:begin
                    if(cpact_col<8)begin
                        for (i=0;i<3;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                        for (i=3;i<5;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                    end
                    else begin
                        for (i=0;i<3;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                        for (i=3;i<5;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                        for (i=0;i<5;i=i+1)begin
                            for(j=2;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                    end
                end
                8'd13:begin
                    if(cpact_col<8)begin
                        for (i=0;i<4;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                        for (i=4;i<5;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                    end
                    else begin
                        for (i=0;i<4;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                        for (i=4;i<5;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                        for (i=0;i<5;i=i+1)begin
                            for(j=2;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                    end
                end
                default:begin
                    if(cpact_col<8)begin
                        for (i=0;i<5;i=i+1)begin
                            for(j=0;j<4;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                    end
                    else begin
                        for (i=0;i<5;i=i+1)begin
                            for(j=0;j<2;j=j+1)begin
                                next_out_psum[i][j] = out_act[cpact_row-i][cpact_col+j]+comp_res[i][j];
                            end
                        end
                        for (i=0;i<5;i=i+1)begin
                            for(j=2;j<4;j=j+1)begin
                                next_out_psum[i][j] = 0;
                            end
                        end
                    end
                end
            endcase
        end
        else begin
            for (i=0;i<5;i=i+1)begin
                for(j=0;j<4;j=j+1)begin
                    next_out_psum[i][j] = 0;
                end

            end
        end
    end
    //combinational for asserting the intput for conv
    always @(*)begin
        if(state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
            //data for computing
            wt_row0 = {weights2D[0][4],weights2D[0][3],weights2D[0][2],weights2D[0][1],weights2D[0][0]};
            wt_row1 = {weights2D[1][4],weights2D[1][3],weights2D[1][2],weights2D[1][1],weights2D[1][0]};
            wt_row2 = {weights2D[2][4],weights2D[2][3],weights2D[2][2],weights2D[2][1],weights2D[2][0]};
            wt_row3 = {weights2D[3][4],weights2D[3][3],weights2D[3][2],weights2D[3][1],weights2D[3][0]};
            wt_row4 = {weights2D[4][4],weights2D[4][3],weights2D[4][2],weights2D[4][1],weights2D[4][0]};
            activation0 = act_rdata0;
            activation1 = act_rdata1;
        end
        else begin
            wt_row0 = 0;
            wt_row1 = 0;
            wt_row2 = 0;
            wt_row3 = 0;
            wt_row4 = 0;
            activation0=0;
            activation1=0;
        end
    end

    //save back to sram and pooling relu quan
    reg [7:0] outrow;
    reg [7:0] next_outrow;
    reg [7:0] outcol;
    reg [7:0] next_outcol;

    always @(posedge clk)begin
        if(!rst_n)begin
            outcol <= 0;
        end
        else begin
            outcol <= next_outcol;
        end
    end
    always @(*)begin
        if(state==PoolingQuan)begin
            if(outcol<0)begin
                next_outcol = outcol + 16;
            end
            else begin
                next_outcol = 0;
            end
        end
        else begin
            next_outcol = 0;
        end
    end

    always @(posedge clk)begin
        if(!rst_n)begin
            outrow <= 0;
        end
        else begin
            outrow <= next_outrow;
        end
    end
    always @(*)begin
        if(state==PoolingQuan)begin
            /*if(outcol==16)begin
                next_outrow = outrow + 2;
            end*/
            next_outrow = outrow+2;
            
        end
        else begin
            next_outrow = 0;
        end
    end

    always @(*)begin
        if(state==PoolingQuan)begin
            for(i=0;i<2;i=i+1)begin
                for(j=0;j<10;j=j+1)begin
                    prq_in[i][j] = out_act[outrow + i][outcol + j];
                end
            end
            for(i=0;i<2;i=i+1)begin
                for(j=10;j<16;j=j+1)begin
                    prq_in[i][j] = 0;
                end
            end
            
        end
        else begin
            for(i=0;i<2;i=i+1)begin
                for(j=0;j<16;j=j+1)begin
                    prq_in[i][j] = 0;
                end
            end
        end
    end

//FSM
    always@(posedge clk) begin
        if(!rst_n) begin
            state <= Pre;
        end
        else begin
            state <= next_state;
        end
    end
    always @*begin
        case(state)
            Pre:begin
                if(start==1'b1)begin
                    next_state=LoadWeight;
                end
                else begin
                    next_state=Pre;
                end
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=0;
                act_addr1=0;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                finish = 0;
            end
            Outchannel:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=0;
                act_addr1=0;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                next_state=Inchannel;
                finish = 0;
            end
            Inchannel:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=0;
                act_addr1=0;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                next_state=LoadWeight;
                finish = 0;
            end
            LoadWeight:begin
                weight_addr0=16'd60 + out_channel*60 + in_channel*10 + row_weight_cnt*2;
                weight_addr1=16'd60 + out_channel*60 + in_channel*10 + row_weight_cnt*2 + 1;
                weight_wea0=4'b0000;
                weight_wea1=4'b0000;
                act_addr0 = 0;
                act_addr1 = 0;
                act_wea0 = 4'b0000;
                act_wea1 = 4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                if(row_weight_cnt==7)begin
                    next_state=LoadAct;
                end
                else begin
                    next_state=LoadWeight;
                end
                finish = 0;
            end
            LoadAct:begin
                next_state=Wait0;
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0 = 16'd256 + in_channel*56 + row_act_cnt*16'd4 + {10'b0,act_cnt [7:2]};
                act_addr1 = 16'd256 + in_channel*56 + row_act_cnt*16'd4 + {10'b0,act_cnt [7:2]}+1;
                act_wea0 = 4'b0000;
                act_wea1 = 4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                finish = 0;
            end
            Wait0:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=16'd256 + in_channel*56 + row_act_cnt*16'd4 + {10'b0,act_cnt [7:2]};
                act_addr1=16'd256 + in_channel*56 + row_act_cnt*16'd4 + {10'b0,act_cnt [7:2]}+1;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                next_state=Wait1;
                finish = 0;
            end
            Wait1:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=16'd256 + in_channel*56 + row_act_cnt*16'd4 + {10'b0,act_cnt [7:2]};
                act_addr1=16'd256 + in_channel*56 + row_act_cnt*16'd4 + {10'b0,act_cnt [7:2]}+1;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                next_state=Comp;
                finish = 0;
            end
            
            Comp:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                //load data (3 cycle later)
                act_addr0=16'd256 + in_channel*56 + row_act_cnt*16'd4 + {10'b0,act_cnt [7:2]};
                act_addr1=16'd256 + in_channel*56 + row_act_cnt*16'd4 + {10'b0,act_cnt [7:2]} + 1;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                if(row_act_cnt==16'd13 && act_cnt==16'd8)begin
                    next_state=Wait2;
                end
                else begin
                    next_state=Comp;
                end
                finish = 0;
            end 
            Wait2:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=0;
                act_addr1=0;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                next_state=Wait3;
                finish = 0;
            end
            Wait3:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=0;
                act_addr1=0;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                next_state=Wait4;
                finish = 0;
            end
            Wait4:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0 = 16'd0;
                act_addr1 = 16'd0;
                act_wdata0 = 32'd0;
                act_wdata1 = 32'd0;
                act_wea0 = 4'b0000;
                act_wea1 = 4'b0000;
                next_state=Wait5;
                finish = 0;
            end
            Wait5:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0 = 16'd0;
                act_addr1 = 16'd0;
                act_wdata0 = 32'd0;
                act_wdata1 = 32'd0;
                act_wea0 = 4'b0000;
                act_wea1 = 4'b0000;
                
                if(in_channel==5)begin
                    next_state=PoolingQuan;
                end
                else begin
                    next_state=Inchannel;
                end
                finish = 0;
            end
            PoolingQuan:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0 = 16'd592 + (( out_channel*5+outrow[7:1] )>>2 )*5 +  ( out_channel*5+outrow[7:1] )%4;
                act_addr1 = 16'd592 + (( out_channel*5+outrow[7:1] )>>2 )*5 +  ( out_channel*5+outrow[7:1] )%4 +1;
                case(( out_channel*5+outrow[7:1] )%4)
                    0:begin
                        act_wdata0 = quanout0;
                        act_wdata1 = { 24'd0,quanout1[7:0] };
                        act_wea0 = 4'b1111;
                        act_wea1 = 4'b0001;
                    end
                    1:begin
                        act_wdata0 = { quanout0[23:0],8'd0 };
                        act_wdata1 = { 16'd0,quanout1[7:0],quanout0[31:24] };
                        act_wea0 = 4'b1110;
                        act_wea1 = 4'b0011;
                    end
                    2:begin
                        act_wdata0 = { quanout0[15:0],16'd0 };
                        act_wdata1 = { 8'd0,quanout1[7:0],quanout0[31:16] };
                        act_wea0 = 4'b1100;
                        act_wea1 = 4'b0111;
                    end
                    3:begin
                        act_wdata0 = { quanout0[7:0],24'd0 };
                        act_wdata1 = { quanout1[7:0],quanout0[31:8] };
                        act_wea0 = 4'b1000;
                        act_wea1 = 4'b1111;
                    end
                    default:begin
                        act_wdata0 = 0;
                        act_wdata1 = 0;
                        act_wea0 = 4'b0000;
                        act_wea1 = 4'b0000;
                    end
                endcase
                
                if(outrow==8)begin
                    if(out_channel==8'd15)begin
                        next_state=Waitend0;
                    end
                    else begin
                        next_state=Outchannel;
                    end
                end
                else begin
                    next_state=PoolingQuan;
                    
                end
                finish = 0;
               
            end
            Waitend0:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=0;
                act_addr1=0;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                next_state=Waitend1;
                finish = 0;
            end
            Waitend1:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=0;
                act_addr1=0;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                next_state=Finish;
                finish = 0;
            end
            Finish:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=0;
                act_addr1=0;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                next_state = Finish;
                finish = 1;
            end
            
            default:  begin
                next_state=Pre;
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=0;
                act_addr1=0;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                finish = 0; 
            end
        endcase
    end

endmodule

//innerproduct module
module innerproduct8_5(
    
    input wire [31:0] act0,
    input wire [31:0] act1,

    input wire signed [39:0] wt_row0,
    input wire signed [39:0] wt_row1,
    input wire signed [39:0] wt_row2,
    input wire signed [39:0] wt_row3,
    input wire signed [39:0] wt_row4,

    output signed [31:0] out_00,
    output signed [31:0] out_01,
    output signed [31:0] out_02,
    output signed [31:0] out_03,
    output signed [31:0] out_10,
    output signed [31:0] out_11,
    output signed [31:0] out_12,
    output signed [31:0] out_13,
    output signed [31:0] out_20,
    output signed [31:0] out_21,
    output signed [31:0] out_22,
    output signed [31:0] out_23,
    output signed [31:0] out_30,
    output signed [31:0] out_31,
    output signed [31:0] out_32,
    output signed [31:0] out_33,
    output signed [31:0] out_40,
    output signed [31:0] out_41,
    output signed [31:0] out_42,
    output signed [31:0] out_43
);

    wire signed [7:0] a0;
    wire signed [7:0] a1;
    wire signed [7:0] a2;
    wire signed [7:0] a3;
    wire signed [7:0] a4;
    wire signed [7:0] a5;
    wire signed [7:0] a6;
    wire signed [7:0] a7;
    assign a0 = act0[ 7: 0];
    assign a1 = act0[15: 8];
    assign a2 = act0[23:16];
    assign a3 = act0[31:24];
    assign a4 = act1[ 7: 0];
    assign a5 = act1[15: 8];
    assign a6 = act1[23:16];
    assign a7 = act1[31:24];

    wire signed [7:0] weight[4:0][4:0];
   


    assign weight[0][0] = wt_row0[ 7: 0];
    assign weight[0][1] = wt_row0[15: 8];
    assign weight[0][2] = wt_row0[23:16];
    assign weight[0][3] = wt_row0[31:24];
    assign weight[0][4] = wt_row0[39:32];
    assign weight[1][0] = wt_row1[ 7: 0];
    assign weight[1][1] = wt_row1[15: 8];
    assign weight[1][2] = wt_row1[23:16];
    assign weight[1][3] = wt_row1[31:24];
    assign weight[1][4] = wt_row1[39:32];
    assign weight[2][0] = wt_row2[ 7: 0];
    assign weight[2][1] = wt_row2[15: 8];
    assign weight[2][2] = wt_row2[23:16];
    assign weight[2][3] = wt_row2[31:24];
    assign weight[2][4] = wt_row2[39:32];
    assign weight[3][0] = wt_row3[ 7: 0];
    assign weight[3][1] = wt_row3[15: 8];
    assign weight[3][2] = wt_row3[23:16];
    assign weight[3][3] = wt_row3[31:24];
    assign weight[3][4] = wt_row3[39:32];
    assign weight[4][0] = wt_row4[ 7: 0];
    assign weight[4][1] = wt_row4[15: 8];
    assign weight[4][2] = wt_row4[23:16];
    assign weight[4][3] = wt_row4[31:24];
    assign weight[4][4] = wt_row4[39:32];
    
    //calculating
    assign out_00 = weight[0][0]*a0 + weight[0][1]*a1 + weight[0][2]*a2 + weight[0][3]*a3 + weight[0][4]*a4;
    assign out_01 = weight[0][0]*a1 + weight[0][1]*a2 + weight[0][2]*a3 + weight[0][3]*a4 + weight[0][4]*a5;
    assign out_02 = weight[0][0]*a2 + weight[0][1]*a3 + weight[0][2]*a4 + weight[0][3]*a5 + weight[0][4]*a6;
    assign out_03 = weight[0][0]*a3 + weight[0][1]*a4 + weight[0][2]*a5 + weight[0][3]*a6 + weight[0][4]*a7;
    assign out_10 = weight[1][0]*a0 + weight[1][1]*a1 + weight[1][2]*a2 + weight[1][3]*a3 + weight[1][4]*a4;
    assign out_11 = weight[1][0]*a1 + weight[1][1]*a2 + weight[1][2]*a3 + weight[1][3]*a4 + weight[1][4]*a5;
    assign out_12 = weight[1][0]*a2 + weight[1][1]*a3 + weight[1][2]*a4 + weight[1][3]*a5 + weight[1][4]*a6;
    assign out_13 = weight[1][0]*a3 + weight[1][1]*a4 + weight[1][2]*a5 + weight[1][3]*a6 + weight[1][4]*a7;
    assign out_20 = weight[2][0]*a0 + weight[2][1]*a1 + weight[2][2]*a2 + weight[2][3]*a3 + weight[2][4]*a4;
    assign out_21 = weight[2][0]*a1 + weight[2][1]*a2 + weight[2][2]*a3 + weight[2][3]*a4 + weight[2][4]*a5;
    assign out_22 = weight[2][0]*a2 + weight[2][1]*a3 + weight[2][2]*a4 + weight[2][3]*a5 + weight[2][4]*a6;
    assign out_23 = weight[2][0]*a3 + weight[2][1]*a4 + weight[2][2]*a5 + weight[2][3]*a6 + weight[2][4]*a7;
    assign out_30 = weight[3][0]*a0 + weight[3][1]*a1 + weight[3][2]*a2 + weight[3][3]*a3 + weight[3][4]*a4;
    assign out_31 = weight[3][0]*a1 + weight[3][1]*a2 + weight[3][2]*a3 + weight[3][3]*a4 + weight[3][4]*a5;
    assign out_32 = weight[3][0]*a2 + weight[3][1]*a3 + weight[3][2]*a4 + weight[3][3]*a5 + weight[3][4]*a6;
    assign out_33 = weight[3][0]*a3 + weight[3][1]*a4 + weight[3][2]*a5 + weight[3][3]*a6 + weight[3][4]*a7;
    assign out_40 = weight[4][0]*a0 + weight[4][1]*a1 + weight[4][2]*a2 + weight[4][3]*a3 + weight[4][4]*a4;
    assign out_41 = weight[4][0]*a1 + weight[4][1]*a2 + weight[4][2]*a3 + weight[4][3]*a4 + weight[4][4]*a5;
    assign out_42 = weight[4][0]*a2 + weight[4][1]*a3 + weight[4][2]*a4 + weight[4][3]*a5 + weight[4][4]*a6;
    assign out_43 = weight[4][0]*a3 + weight[4][1]*a4 + weight[4][2]*a5 + weight[4][3]*a6 + weight[4][4]*a7;

   
endmodule    

//pooling module
module poolReluQuan28_7(
    input wire signed [31:0] scale,

    input wire signed [31:0] in0_0 ,
    input wire signed [31:0] in0_1 ,
    input wire signed [31:0] in0_2 ,
    input wire signed [31:0] in0_3 ,
    input wire signed [31:0] in0_4 ,
    input wire signed [31:0] in0_5 ,
    input wire signed [31:0] in0_6 ,
    input wire signed [31:0] in0_7 ,
    input wire signed [31:0] in0_8 ,
    input wire signed [31:0] in0_9 ,
    input wire signed [31:0] in0_10,
    input wire signed [31:0] in0_11,
    input wire signed [31:0] in0_12,
    input wire signed [31:0] in0_13,
    input wire signed [31:0] in0_14,
    input wire signed [31:0] in0_15,
    input wire signed [31:0] in1_0 ,
    input wire signed [31:0] in1_1 ,
    input wire signed [31:0] in1_2 ,
    input wire signed [31:0] in1_3 ,
    input wire signed [31:0] in1_4 ,
    input wire signed [31:0] in1_5 ,
    input wire signed [31:0] in1_6 ,
    input wire signed [31:0] in1_7 ,
    input wire signed [31:0] in1_8 ,
    input wire signed [31:0] in1_9 ,
    input wire signed [31:0] in1_10,
    input wire signed [31:0] in1_11,
    input wire signed [31:0] in1_12,
    input wire signed [31:0] in1_13,
    input wire signed [31:0] in1_14,
    input wire signed [31:0] in1_15,
    output [31:0]act0,
    output [31:0]act1

);
//pooling
    wire signed [31:0] poolhf_0 ;
    wire signed [31:0] poolhf_1 ;
    wire signed [31:0] poolhf_2 ;
    wire signed [31:0] poolhf_3 ;
    wire signed [31:0] poolhf_4 ;
    wire signed [31:0] poolhf_5 ;
    wire signed [31:0] poolhf_6 ;
    wire signed [31:0] poolhf_7 ;
    wire signed [31:0] poolhf_8 ;
    wire signed [31:0] poolhf_9 ;
    wire signed [31:0] poolhf_10;
    wire signed [31:0] poolhf_11;
    wire signed [31:0] poolhf_12;
    wire signed [31:0] poolhf_13;
    wire signed [31:0] poolhf_14;
    wire signed [31:0] poolhf_15;
    assign poolhf_0  = (in0_0  > in1_0 ) ? in0_0  : in1_0  ;
    assign poolhf_1  = (in0_1  > in1_1 ) ? in0_1  : in1_1  ;
    assign poolhf_2  = (in0_2  > in1_2 ) ? in0_2  : in1_2  ;
    assign poolhf_3  = (in0_3  > in1_3 ) ? in0_3  : in1_3  ;
    assign poolhf_4  = (in0_4  > in1_4 ) ? in0_4  : in1_4  ;
    assign poolhf_5  = (in0_5  > in1_5 ) ? in0_5  : in1_5  ;
    assign poolhf_6  = (in0_6  > in1_6 ) ? in0_6  : in1_6  ;
    assign poolhf_7  = (in0_7  > in1_7 ) ? in0_7  : in1_7  ;
    assign poolhf_8  = (in0_8  > in1_8 ) ? in0_8  : in1_8  ;
    assign poolhf_9  = (in0_9  > in1_9 ) ? in0_9  : in1_9  ;
    assign poolhf_10 = (in0_10 > in1_10) ? in0_10 : in1_10 ;
    assign poolhf_11 = (in0_11 > in1_11) ? in0_11 : in1_11 ;
    assign poolhf_12 = (in0_12 > in1_12) ? in0_12 : in1_12 ;
    assign poolhf_13 = (in0_13 > in1_13) ? in0_13 : in1_13 ;
    assign poolhf_14 = (in0_14 > in1_14) ? in0_14 : in1_14 ;
    assign poolhf_15 = (in0_15 > in1_15) ? in0_15 : in1_15 ;

    wire signed [31:0] pool_0 ;
    wire signed [31:0] pool_1 ;
    wire signed [31:0] pool_2 ;
    wire signed [31:0] pool_3 ;
    wire signed [31:0] pool_4 ;
    wire signed [31:0] pool_5 ;
    wire signed [31:0] pool_6 ;
    wire signed [31:0] pool_7 ;

    assign pool_0  = (poolhf_0  > poolhf_1  ) ? poolhf_0   : poolhf_1  ;
    assign pool_1  = (poolhf_2  > poolhf_3  ) ? poolhf_2   : poolhf_3  ;
    assign pool_2  = (poolhf_4  > poolhf_5  ) ? poolhf_4   : poolhf_5  ;
    assign pool_3  = (poolhf_6  > poolhf_7  ) ? poolhf_6   : poolhf_7  ;
    assign pool_4  = (poolhf_8  > poolhf_9  ) ? poolhf_8   : poolhf_9  ;
    assign pool_5  = (poolhf_10 > poolhf_11 ) ? poolhf_10  : poolhf_11 ;
    assign pool_6  = (poolhf_12 > poolhf_13 ) ? poolhf_12  : poolhf_13 ;
    assign pool_7  = (poolhf_14 > poolhf_15 ) ? poolhf_14  : poolhf_15 ;
//ReLu
//ReLu
    wire signed [31:0] relu_0 ;
    wire signed [31:0] relu_1 ;
    wire signed [31:0] relu_2 ;
    wire signed [31:0] relu_3 ;
    wire signed [31:0] relu_4 ;
    wire signed [31:0] relu_5 ;
    wire signed [31:0] relu_6 ;
    wire signed [31:0] relu_7 ;

    assign relu_0  = (!pool_0 [31]) ? pool_0  : 0;
    assign relu_1  = (!pool_1 [31]) ? pool_1  : 0;
    assign relu_2  = (!pool_2 [31]) ? pool_2  : 0;
    assign relu_3  = (!pool_3 [31]) ? pool_3  : 0;
    assign relu_4  = (!pool_4 [31]) ? pool_4  : 0;
    assign relu_5  = (!pool_5 [31]) ? pool_5  : 0;
    assign relu_6  = (!pool_6 [31]) ? pool_6  : 0;
    assign relu_7  = (!pool_7 [31]) ? pool_7  : 0;


//quantize
    wire signed [63:0] sc_0;
    wire signed [63:0] sc_1;
    wire signed [63:0] sc_2;
    wire signed [63:0] sc_3;
    wire signed [63:0] sc_4;
    wire signed [63:0] sc_5;
    wire signed [63:0] sc_6;
    wire signed [63:0] sc_7;

    assign sc_0 = relu_0 * scale;
    assign sc_1 = relu_1 * scale;
    assign sc_2 = relu_2 * scale;
    assign sc_3 = relu_3 * scale;
    assign sc_4 = relu_4 * scale;
    assign sc_5 = relu_5 * scale;
    assign sc_6 = relu_6 * scale;
    assign sc_7 = relu_7 * scale;

    wire signed [7:0] clamp_0;
    wire signed [7:0] clamp_1;
    wire signed [7:0] clamp_2;
    wire signed [7:0] clamp_3;
    wire signed [7:0] clamp_4;
    wire signed [7:0] clamp_5;
    wire signed [7:0] clamp_6;
    wire signed [7:0] clamp_7;

    assign clamp_0 = (sc_0[63:23]==0) ? sc_0[23:16] : 8'd127;
    assign clamp_1 = (sc_1[63:23]==0) ? sc_1[23:16] : 8'd127;
    assign clamp_2 = (sc_2[63:23]==0) ? sc_2[23:16] : 8'd127;
    assign clamp_3 = (sc_3[63:23]==0) ? sc_3[23:16] : 8'd127;
    assign clamp_4 = (sc_4[63:23]==0) ? sc_4[23:16] : 8'd127;
    assign clamp_5 = (sc_5[63:23]==0) ? sc_5[23:16] : 8'd127;
    assign clamp_6 = (sc_6[63:23]==0) ? sc_6[23:16] : 8'd127;
    assign clamp_7 = (sc_7[63:23]==0) ? sc_7[23:16] : 8'd127;



    assign act0 = { clamp_3,clamp_2,clamp_1,clamp_0 };
    assign act1 = { clamp_7,clamp_6,clamp_5,clamp_4 };

endmodule