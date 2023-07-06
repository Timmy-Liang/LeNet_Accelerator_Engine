module conv3(
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
    //parameter [3:0] Inchannel=4'd6;
    parameter [3:0] LoadWeight=4'd2;
    parameter [3:0] LoadAct=4'd3;
    parameter [3:0] Comp=4'd4;
    parameter [3:0] Quan=4'd5;


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
    reg [39:0]weight0;
    reg [39:0]weight1;
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

    reg [31:0] prq_in;
    wire [7:0] quanout;
    reluQuan1 rq(
        .scale (scale),
        .in(prq_in),
        .out(quanout)
    );

    
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
    /*reg [7:0]in_channel;
    reg [7:0]next_in_channel;
    always @(posedge clk) begin
        if(!rst_n)begin
            in_channel <= 0;
        end
        else begin
            in_channel <= next_in_channel;
        end
    end*/
    

    //row weight count
    reg [15:0]weight_cnt;
    reg [15:0]next_weight_cnt;
    always@(posedge clk) begin
        if(!rst_n) begin
            weight_cnt <= 15'd0;
        end
        else begin
            weight_cnt <= next_weight_cnt;
        end
    end
    always@(*)begin
        if (state==LoadAct||state==Comp||state==Wait0||state==Wait1)begin
            next_weight_cnt =weight_cnt+8;
        end  
        else begin
            next_weight_cnt = 0;
        end
    end
//loading weight
    reg [15:0]loading_weight_cnt;
    reg [15:0]next_loading_weight_cnt;
    always@(posedge clk) begin
        if(!rst_n) begin
            loading_weight_cnt <= 4'd0;
        end
        else begin
            loading_weight_cnt <= next_loading_weight_cnt;
        end
    end
    always@(*)begin
        if (state==LoadAct||state==Comp||state==Wait0||state==Wait1||state==Wait2||state==Wait3||state==Wait4||state==Wait5)begin
            next_loading_weight_cnt =loading_weight_cnt+8;
        end  
        else begin
            next_loading_weight_cnt = 0;
        end
    end
    //save weight to array

    integer i;
    integer j;
    
     //id of to-load activation 
    reg [15:0]act_cnt;
    reg [15:0]next_act_cnt;
    always@(posedge clk)begin
        if(!rst_n) begin
            act_cnt<=16'd0;
        end
        else begin 
            act_cnt <= next_act_cnt;
        end
    end
    always @(*)begin
        if (state==LoadAct||state==Wait0||state==Wait1||state==Comp)begin
            next_act_cnt = act_cnt+16'd8;
        end
        else begin
            next_act_cnt = 0;
        end
    end
    //row act
   
    //computing activation
    reg [15:0]cpact_cnt;
    reg [15:0]next_cpact_cnt;
    always@(posedge clk)begin
        if(!rst_n) begin
            cpact_cnt<=15'd0;
        end
        else begin 
            cpact_cnt <= next_cpact_cnt;
        end
    end
    always @(*)begin
        if (state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
            next_cpact_cnt = cpact_cnt+8'd8;
        end
        else begin
            next_cpact_cnt = 0;
        end
    end
    


    //save the psum
    //output array for a channel
    reg signed [31:0] out_act;
    reg signed [31:0] next_out_psum; 
    //integer i,j;
    always@(posedge clk)begin
        if(!rst_n) begin
            out_act <= 0;
        end
        else begin 
            if(state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
                out_act <= next_out_psum;
            end
            else begin
                //debug
                if(state==Outchannel)begin
                    out_act <= 0;
                end
                else begin
                    out_act <= out_act;
                end
                
            end
        end
        
    end
    //combinational saving and adding the psum 
    always @(*)begin
        if(state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
            next_out_psum = out_act + comp_res;
        end
        else begin
            next_out_psum = 0;
        end
    end
    
//combinational for asserting the intput for conv
    always @(*)begin
        if(state==Comp||state==Wait2||state==Wait3||state==Wait4)begin
            //data for computing
            weight0 = weight_rdata0;
            weight1 = weight_rdata1;
            activation0 = act_rdata0;
            activation1 = act_rdata1;
        end
        else begin
            weight0 = 0;
            weight1 = 0;
            activation0=0;
            activation1=0;
        end
    end
    //save back to sram and pooling relu quan
    always @(*)begin
        if(state==Quan)begin
            prq_in=out_act;
        end
        else begin
            prq_in = 0;
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
                if(start==1'b1)begin
                    next_state=LoadAct;
                end
                else begin
                    next_state=Pre;
                end
                finish = 0;
            end
            Outchannel:begin
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
                next_state=LoadAct;
                finish = 0;
            end
            LoadAct:begin
                next_state=Wait0;
                weight_addr0=16'd1020 + out_channel*100 + weight_cnt[15:2];
                weight_addr1=16'd1020 + out_channel*100 + weight_cnt[15:2] + 1;
                weight_wea0=4'b0000;
                weight_wea1=4'b0000;
                act_addr0 = 16'd592 + act_cnt [15:2];
                act_addr1 = 16'd592 + act_cnt [15:2] + 1;
                act_wea0 = 4'b0000;
                act_wea1 = 4'b0000;
                act_wdata0 = 32'd0;
                act_wdata1 = 32'd0;
                finish = 0;
            end
            Wait0:begin
                weight_addr0=16'd1020 + out_channel*100 + weight_cnt[15:2];
                weight_addr1=16'd1020 + out_channel*100 + weight_cnt[15:2] + 1;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=16'd592 + act_cnt [15:2];
                act_addr1=16'd592 + act_cnt [15:2] + 1;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 32'd0;
                act_wdata1 = 32'd0;
                next_state=Wait1;
                finish = 0;
            end
            Wait1:begin
                weight_addr0=16'd1020 + out_channel*100 + weight_cnt[15:2];
                weight_addr1=16'd1020 + out_channel*100 + weight_cnt[15:2] + 1;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0=16'd592 + act_cnt [15:2];
                act_addr1=16'd592 + act_cnt [15:2] + 1;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 32'd0;
                act_wdata1 = 32'd0;
                next_state=Comp;
                finish = 0;
            end
            
            Comp:begin
                weight_addr0=16'd1020 + out_channel*100 + weight_cnt[15:2];
                weight_addr1=16'd1020 + out_channel*100 + weight_cnt[15:2] + 1;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                //load data (3 cycle later)
                act_addr0=16'd592 + act_cnt [15:2];
                act_addr1=16'd592 + act_cnt [15:2] + 1;
                act_wea0=4'b0000;
                act_wea1=4'b0000;
                act_wdata0 = 32'd0;
                act_wdata1 = 32'd0;
                if(act_cnt==16'd392)begin
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
                act_wdata0 = 32'd0;
                act_wdata1 = 32'd0;
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
                act_wdata0 = 32'd0;
                act_wdata1 = 32'd0;
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
                
                next_state=Quan;
                finish = 0;
            end
            Quan:begin
                weight_addr0 = 16'd0;
                weight_addr1 = 16'd0;
                weight_wea0 = 4'b0000;
                weight_wea1 = 4'b0000;
                act_addr0 = 16'd692 + out_channel[7:2] ;
                act_addr1 = 0;
                case( out_channel[1:0])
                    2'd0:begin
                        act_wdata0 = {24'd0,quanout};
                        act_wdata1 = 0;
                        act_wea0 = 4'b0001;
                        act_wea1 = 4'b0000;
                    end
                    2'd1:begin
                        act_wdata0 = { 16'd0,quanout,8'd0 };
                        act_wdata1 = 0;
                        act_wea0 = 4'b0010;
                        act_wea1 = 4'b0000;
                    end
                    2'd2:begin
                        act_wdata0 = { 8'd0,quanout,16'd0 };
                        act_wdata1 = 0;
                        act_wea0 = 4'b0100;
                        act_wea1 = 4'b0000;
                    end
                    2'd3:begin
                        act_wdata0 = { quanout,24'd0 };
                        act_wdata1 = 0;
                        act_wea0 = 4'b1000;
                        act_wea1 = 4'b0000;
                    end
                    default:begin
                        act_wdata0 = 0;
                        act_wdata1 = 0;
                        act_wea0 = 4'b0000;
                        act_wea1 = 4'b0000;
                    end
                endcase
                
                
                if(out_channel==8'd119)begin
                    next_state=Waitend0;
                end
                else begin
                    next_state=Outchannel;
                end
                finish = 0;
                
               
            end
            Waitend0:begin
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
                next_state=Waitend1;
                finish = 0;
            end
            Waitend1:begin
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
                next_state=Finish;
                finish = 0;
            end
            Finish:begin
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
                next_state = Finish;
                finish = 1;
            end
            
            default:  begin
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
                next_state=Pre; 
                finish = 0;
            end

        endcase
    end

endmodule

module innerproduct8(
    input signed [7:0] weight0,
    input signed [7:0] weight1,
    input signed [7:0] weight2,
    input signed [7:0] weight3,
    input signed [7:0] weight4,
    input signed [7:0] weight5,
    input signed [7:0] weight6,
    input signed [7:0] weight7,
    
    input signed [7:0] act0,
    input signed [7:0] act1,
    input signed [7:0] act2,
    input signed [7:0] act3,
    input signed [7:0] act4,
    input signed [7:0] act5,
    input signed [7:0] act6,
    input signed [7:0] act7,
    output signed [31:0] out
);

    wire signed[31:0] wr0;
    wire signed[31:0] wr1;
    wire signed[31:0] wr2;
    wire signed[31:0] wr3;
    wire signed[31:0] wr4;
    wire signed[31:0] wr5;
    wire signed[31:0] wr6;
    wire signed[31:0] wr7;

    
    assign wr0 = act0 * weight0;
    assign wr1 = act1 * weight1;
    assign wr2 = act2 * weight2;
    assign wr3 = act3 * weight3;
    assign wr4 = act4 * weight4;
    assign wr5 = act5 * weight5;
    assign wr6 = act6 * weight6;
    assign wr7 = act7 * weight7;

    assign out = wr0 + wr1 + wr2 + wr3 + wr4 + wr5 + wr6 + wr7;


endmodule
//relu quan
module reluQuan1(
    input signed [31:0]scale,
    input signed [31:0]in,
    output signed [7:0]out
);
    wire signed [31:0]relu;
    assign relu = (!in[31]) ? in : 0;

    wire signed [63:0]scaled;
    assign scaled = relu * scale;

    assign out = (scaled[63:23]==0) ? scaled[23:16] : 8'd127;
endmodule