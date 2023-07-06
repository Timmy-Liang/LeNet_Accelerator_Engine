module fc7 (
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
    // Add your design here

    reg [3:0] state;
    reg [3:0] next_state;
    
    
    parameter [3:0] Pre=4'd0;
    parameter [3:0] PreLoad=4'd1;
    parameter [3:0] Comp=4'd2;
    parameter [3:0] Quan=4'd3;
    parameter [3:0] WriteData=4'd4;
    parameter [3:0] Wait_write0=4'd5;
    parameter [3:0] Wait_write1=4'd6;

    parameter [3:0] Finish=4'd8;
    parameter [3:0] Wait0=4'd10;
    parameter [3:0] Wait1=4'd11;
    parameter [3:0] Wait2=4'd12;
    parameter [3:0] Wait3=4'd13;
    parameter [3:0] Wait4=4'd14;

    
    reg [31:0]weight0;
    reg [31:0]weight1;
    reg [31:0]activation0;
    reg [31:0]activation1;
    wire signed [31:0]comp_res;
    innerproduct8 inpro8(
        .weight0(weight0[7 :0 ]),
        .weight1(weight0[15:8 ]),
        .weight2(weight0[23:16]),
        .weight3(weight0[31:24]),
        .weight4(weight1[7 :0 ]),
        .weight5(weight1[15:8 ]),
        .weight6(weight1[23:16]),
        .weight7(weight1[31:24]),
        
        .act0(activation0[7 :0 ]),
        .act1(activation0[15:8 ]),
        .act2(activation0[23:16]),
        .act3(activation0[31:24]),
        .act4(activation1[7 :0 ]),
        .act5(activation1[15:8 ]),
        .act6(activation1[23:16]),
        .act7(activation1[31:24]),

        .out(comp_res)
    );
    //ReLu, Quantization, Clamp
    reg [31:0]in0;
    reg [31:0]in1;
    //debug load bias
    reg [31:0]bias0;
    reg [31:0]bias1;
    wire [31:0]bias_out_act0;
    wire [31:0]bias_out_act1;
    relu_quan_bias32 reluq(
        .in0( in0 ),
        .in1( in1 ),
        .bias0( bias0 ),
        .bias1( bias1 ),
        .out0(bias_out_act0),
        .out1(bias_out_act1)
    );


    
    //weight count
    reg [15:0]weight_count;//0-20,21-41,42-62,63-83......
    reg [15:0]next_weight_count;
    always@(posedge clk) begin
        if(!rst_n) begin
            weight_count <= 16'd0;
        end
        else begin
            weight_count <= next_weight_count;
        end
    end
    always@(*)begin
        if (state==PreLoad||state==Wait0||state==Wait1||state==Comp)begin
                if(weight_count==16'd80)begin //0,2,4,...18,20,then 21,23,25...39,41,then 42,44...
                    next_weight_count =0; 
                end
                else next_weight_count =weight_count+16'd8;
            end
        else begin
            next_weight_count = weight_count;
        end
    end
    reg [15:0]row_weight_count;
    reg [15:0]next_row_weight_count;
    always@(posedge clk) begin
        if(!rst_n) begin
            row_weight_count <= 16'd0;
        end
        else begin
            row_weight_count <= next_row_weight_count;
        end
    end
    always@(*)begin
        if(weight_count==16'd80)begin //
            if(state==PreLoad||state==Wait0||state==Wait1||state==Comp)begin
                next_row_weight_count =row_weight_count+16'd1; 
            end
            else next_row_weight_count =row_weight_count; 
        end  
        else begin
            next_row_weight_count = row_weight_count;
        end
    end

    //weight counter to record what is currently computing ;
    reg [15:0]cpwt_count;
    reg [15:0]next_cpwt_count;
    always@(posedge clk) begin
        if(!rst_n) begin
            cpwt_count <= 16'd0;
        end
        else begin
            cpwt_count <= next_cpwt_count;
        end
    end
    always@(*)begin
        if (state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
                if(cpwt_count==16'd80)begin 
                    next_cpwt_count =0; 
                end
                else next_cpwt_count = cpwt_count+16'd8;
            end
        else begin
            next_cpwt_count = cpwt_count;
        end
    end
    reg [15:0]row_cpwt_count;
    reg [15:0]next_row_cpwt_count;
    always@(posedge clk) begin
        if(!rst_n) begin
            row_cpwt_count <= 16'd0;
        end
        else begin
            row_cpwt_count <= next_row_cpwt_count;
        end
    end
    always@(*)begin
        if(cpwt_count==16'd80)begin //
            if(state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
                next_row_cpwt_count =row_cpwt_count+16'd1; 
            end
            else next_row_cpwt_count =row_cpwt_count; 
        end  
        else begin
            next_row_cpwt_count = row_cpwt_count;
        end
    end

    
    //id of to-load activation 
    reg [7:0]cur_act_id;
    reg [7:0]next_cur_act_id;
    always@(posedge clk)begin
        if(!rst_n) begin
            cur_act_id<=8'd0;
        end
        else begin 
            cur_act_id <= next_cur_act_id;
        end
    end
    always @(*)begin
        if (state==PreLoad||state==Wait0||state==Wait1||state==Comp)begin
                if(cur_act_id==16'd80)begin //0,2,4,...18,20,then 21,23,25...39,41,then 42,44...
                    next_cur_act_id = 0; 
                end
                else next_cur_act_id = cur_act_id+16'd8;
            end
        else begin
            next_cur_act_id = cur_act_id;
        end
    end

    //id of computing act
    reg [7:0]cur_cpact_id;
    reg [7:0]next_cur_cpact_id;
    always@(posedge clk)begin
        if(!rst_n) begin
            cur_cpact_id<=8'd0;
        end
        else begin 
            cur_cpact_id <= next_cur_cpact_id;
        end
    end
    always @(*)begin
        if (state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
                if(cur_cpact_id==16'd80)begin //0,2,4,...18,20,then 21,23,25...39,41,then 42,44...
                    next_cur_cpact_id = 0; 
                end
                else next_cur_cpact_id = cur_cpact_id+16'd8;
            end
        else begin
            next_cur_cpact_id = cur_cpact_id;
        end
    end

    //save result
    reg signed[31:0]out_act[9:0];//10個 32 bit
    reg signed[31:0]next_out_psum;
    integer  i;
    always@(posedge clk)begin
        if(!rst_n) begin
            for (i=0;i<10;i=i+1)begin
                out_act[i]<=0;
            end
        end
        else begin 
            out_act[row_cpwt_count] <= next_out_psum;
        end
    end
    always @(*)begin
        if(state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
            next_out_psum = out_act[row_cpwt_count] + comp_res;
        end
        else begin
            next_out_psum = out_act[row_cpwt_count];
        end
    end
    
    //out id 
    reg [7:0]out_id_cnt;
    reg [7:0]next_out_id_cnt;
    always @(posedge clk)begin
        if(!rst_n)begin
            out_id_cnt <= 0;
        end
        else begin
            out_id_cnt <= next_out_id_cnt;
        end
    end
    always @(*)begin
        if(state==Quan)begin
            if(out_id_cnt==8'd8)begin
               next_out_id_cnt = 0; 
            end
            else begin
                next_out_id_cnt = out_id_cnt + 2;
            end
        end
        else begin
            next_out_id_cnt = out_id_cnt;
        end
    end
    
    always @(*)begin
        if(state==Quan)begin
            in0 = out_act[out_id_cnt + 0];
            in1 = out_act[out_id_cnt + 1];
        end
        else begin
            in0 = 0;
            in1 = 0;
        end
    end
    //control the input of innerproduct
    always @(*)begin
        if(state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
            if(cur_cpact_id==80)begin
                weight0=weight_rdata0;
                weight1=0; 
                activation0=act_rdata0;
                activation1=0;
            end
            else begin
                weight0=weight_rdata0;
                weight1=weight_rdata1; 
                activation0=act_rdata0;
                activation1=act_rdata1;
            end
        end
        else begin
            weight0=0;
            weight1=0; 
            activation0=0;
            activation1=0;
        end
    end
    //load bias
    reg [3:0] bias_cnt;
    reg [3:0] next_bias_cnt;
    always @(posedge clk)begin
        if(!rst_n)begin
            bias_cnt <= 0;
        end
        else begin
            bias_cnt <= next_bias_cnt;
        end
    end
    always @(*)begin
        if(state==Wait2||state==Wait3||state==Wait4||state==Quan)begin
            next_bias_cnt = bias_cnt + 2;
        end
        else begin
            next_bias_cnt = bias_cnt;
        end
    end
    always @(*)begin
        if(state==Quan)begin
            bias0 = weight_rdata0;
            bias1 = weight_rdata1;
        end
        else begin
            bias0 = 0;
            bias1 = 0;
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
                weight_addr0=0;
                weight_addr1=0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_wea0  = 4'b0000;
                act_addr0 = 16'd0;
                act_wea1  = 4'b000; 
                act_addr1 = 16'd0 ;
                act_wdata0 = 32'd0;
                act_wdata1 = 32'd0;
                if(start==1'b1)begin
                    next_state=PreLoad;
                end
                else begin
                    next_state=Pre;
                end
                finish = 0;
            end
            PreLoad:begin
                next_state=Wait0;
                act_addr0=16'd722 + {10'b0,cur_act_id [7:2]};
                act_addr1=16'd722 + {10'b0,cur_act_id [7:2]}+1;
                weight_addr0=16'd15540 + row_weight_count*16'd21 + weight_count[15:2];
                weight_addr1=16'd15540 + row_weight_count*16'd21 + weight_count[15:2]+16'd1;
                
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                finish = 0;
            end
            Wait0:begin
                act_addr0=16'd722 + {10'b0,cur_act_id [7:2]};
                act_addr1=16'd722 + {10'b0,cur_act_id [7:2]}+1;
                weight_addr0=16'd15540 + row_weight_count*16'd21 + weight_count[15:2];
                weight_addr1=16'd15540 + row_weight_count*16'd21 + weight_count[15:2]+16'd1;
                next_state=Wait1;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                finish = 0;
            end
            Wait1:begin
                act_addr0=16'd722 + {10'b0,cur_act_id [7:2]};
                act_addr1=16'd722 + {10'b0,cur_act_id [7:2]}+1;
                weight_addr0=16'd15540 + row_weight_count*16'd21 + weight_count[15:2];
                weight_addr1=16'd15540 + row_weight_count*16'd21 + weight_count[15:2]+16'd1;
                next_state=Comp;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                finish = 0;
            end
            
            Comp:begin
                //load data (3 cycle later)
                act_addr0=16'd722 + {10'b0,cur_act_id [7:2]};
                act_addr1=16'd722 + {10'b0,cur_act_id [7:2]}+1;
                weight_addr0=16'd15540 + row_weight_count*16'd21 + weight_count[15:2];
                weight_addr1=16'd15540 + row_weight_count*16'd21 + weight_count[15:2]+16'd1;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                //data for computing
                if(weight_count==80 && row_weight_count==16'd9)begin
                    next_state=Wait2;
                end
                else begin
                    next_state=Comp;
                end
                finish = 0;
            end 
            Wait2:begin
                act_addr0=0;
                act_addr1=0;
                weight_addr0=16'd15750 + bias_cnt;
                weight_addr1=16'd15750 + bias_cnt + 1;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                next_state=Wait3;
                finish = 0;
            end
            Wait3:begin
                act_addr0=0;
                act_addr1=0;
                weight_addr0=16'd15750 + bias_cnt;
                weight_addr1=16'd15750 + bias_cnt + 1;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                next_state=Wait4;
                finish = 0;
            end
            Wait4:begin
                weight_addr0=16'd15750 + bias_cnt;
                weight_addr1=16'd15750 + bias_cnt + 1;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=0;
                act_addr1=0;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 0;
                act_wdata1 = 0;
                next_state=Quan;
                finish = 0;
            end
            Quan:begin
                next_state=WriteData;
                weight_addr0=16'd15750 + bias_cnt;
                weight_addr1=16'd15750 + bias_cnt + 1;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_wea0  = 4'b1111;
                act_addr0 = 16'd743 + out_id_cnt;
                act_wea1  = 4'b1111; 
                act_addr1 = 16'd743 + out_id_cnt + 1;
                act_wdata0 = bias_out_act0;
                act_wdata1 = bias_out_act1;
                if(out_id_cnt==8)begin
                    next_state = Wait_write0;
                end
                else begin
                    next_state = Quan;
                end
                finish = 0;
                
            end
            Wait_write0:begin
                weight_addr0=0;
                weight_addr1=0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_wea0  = 4'b0000;
                act_addr0 = 16'd0;
                act_wea1  = 4'b000; 
                act_addr1 = 16'd0 ;
                act_wdata0 = 32'd0;
                act_wdata1 = 32'd0;
                next_state = Wait_write1;
                finish = 0;
            end
            Wait_write1:begin
                weight_addr0=0;
                weight_addr1=0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_wea0  = 4'b0000;
                act_addr0 = 16'd0;
                act_wea1  = 4'b000; 
                act_addr1 = 16'd0 ;
                act_wdata0 = 32'd0;
                act_wdata1 = 32'd0;
                next_state = Finish;
                finish = 0;
            end
            Finish:begin
                weight_addr0=0;
                weight_addr1=0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_wea0  = 4'b0000;
                act_addr0 = 16'd0;
                act_wea1  = 4'b000; 
                act_addr1 = 16'd0 ;
                act_wdata0 = 32'd0;
                act_wdata1 = 32'd0;
                next_state = Finish;
                finish = 1;
            end
            default:  begin
                weight_addr0=0;
                weight_addr1=0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_wea0  = 4'b0000;
                act_addr0 = 16'd0;
                act_wea1  = 4'b000; 
                act_addr1 = 16'd0 ;
                act_wdata0 = 32'd0;
                act_wdata1 = 32'd0;
                next_state=Pre;
                finish = 0;
            end 
        endcase
    end
endmodule

module relu_quan_bias32(
    input signed [31:0]in0,
    input signed [31:0]in1,
    input signed [31:0]bias0,
    input signed [31:0]bias1,
    output signed [31:0]out0,
    output signed [31:0]out1
);
    assign out0 = in0 + bias0;
    assign out1 = in1 + bias1;

endmodule