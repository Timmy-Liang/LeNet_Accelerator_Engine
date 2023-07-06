module lenet (
    input wire clk,
    input wire rst_n,

    input wire compute_start,
    output reg compute_finish,

    // Quantization scale
    input wire [31:0] scale_CONV1,
    input wire [31:0] scale_CONV2,
    input wire [31:0] scale_CONV3,
    input wire [31:0] scale_FC1,
    input wire [31:0] scale_FC2,

    // Weight sram, dual port
    output reg [ 3:0] sram_weight_wea0,
    output reg [15:0] sram_weight_addr0,
    output reg [31:0] sram_weight_wdata0,
    input wire [31:0] sram_weight_rdata0,
    output reg [ 3:0] sram_weight_wea1,
    output reg [15:0] sram_weight_addr1,
    output reg [31:0] sram_weight_wdata1,
    input wire [31:0] sram_weight_rdata1,

    // Activation sram, dual port
    output reg [ 3:0] sram_act_wea0,
    output reg [15:0] sram_act_addr0,
    output reg [31:0] sram_act_wdata0,
    input wire [31:0] sram_act_rdata0,
    output reg [ 3:0] sram_act_wea1,
    output reg [15:0] sram_act_addr1,
    output reg [31:0] sram_act_wdata1,
    input wire [31:0] sram_act_rdata1
);
    // Add your design here
    //Buffer
    // Quantization scale
    reg [31:0] sc_CONV1;
    reg [31:0] sc_CONV2;
    reg [31:0] sc_CONV3;
    reg [31:0] sc_FC1;
    reg [31:0] sc_FC2;

    // Weight sram; dual port
    reg [ 3:0] weight_wea0;
    reg [15:0] weight_addr0;
    reg [31:0] weight_wdata0;
    reg [31:0] weight_rdata0;
    reg [ 3:0] weight_wea1;
    reg [15:0] weight_addr1;
    reg [31:0] weight_wdata1;
    reg [31:0] weight_rdata1;

    // Activation sram; dual port
    reg [ 3:0] act_wea0;
    reg [15:0] act_addr0;
    reg [31:0] act_wdata0;
    reg [31:0] act_rdata0;
    reg [ 3:0] act_wea1;
    reg [15:0] act_addr1;
    reg [31:0] act_wdata1;
    reg [31:0] act_rdata1;
    
    always @(posedge clk)begin
        if(!rst_n)begin
            sc_CONV1 <= 0;
            sc_CONV2 <= 0;
            sc_CONV3 <= 0;
            sc_FC1 <= 0;
            sc_FC2 <= 0;

            weight_rdata0 <= 0;
            weight_rdata1 <= 0;
            act_rdata1 <= 0;//in
            act_rdata0 <= 0;//in

            sram_weight_wea0 <= 0;
            sram_weight_addr0 <= 0;
            sram_weight_wdata0 <= 0;
            sram_weight_wea1 <= 0;
            sram_weight_addr1 <= 0;
            sram_weight_wdata1 <= 0;

            // Activation sram; dual port
            sram_act_wea0 <= 0;
            sram_act_addr0 <=0;
            sram_act_wdata0 <=0;
            sram_act_wea1 <= 0;
            sram_act_addr1 <= 0;
            sram_act_wdata1 <= 0;
        end
        else begin
            sc_CONV1 <= scale_CONV1;
            sc_CONV2 <= scale_CONV2;
            sc_CONV3 <= scale_CONV3;
            sc_FC1 <= scale_FC1;
            sc_FC2 <= scale_FC2;
            weight_rdata0 <= sram_weight_rdata0;
            weight_rdata1 <= sram_weight_rdata1;
            act_rdata0 <= sram_act_rdata0;//in
            act_rdata1 <= sram_act_rdata1;//in

            // Weight sram; dual port
            sram_weight_wea0 <= weight_wea0;
            sram_weight_addr0 <= weight_addr0;
            sram_weight_wdata0 <= weight_wdata0;
            sram_weight_wea1 <= weight_wea1;
            sram_weight_addr1 <= weight_addr1;
            sram_weight_wdata1 <= weight_wdata1;
            // Activation sram; dual port
            sram_act_wea0 <= act_wea0;
            sram_act_addr0 <= act_addr0;
            sram_act_wdata0 <=act_wdata0;
            sram_act_wea1 <= act_wea1;
            sram_act_addr1 <= act_addr1;
            sram_act_wdata1 <= act_wdata1;
        end
    end


    //FSM
    reg [3:0] state;
    reg [3:0] next_state;

    parameter [3:0] Pre     =4'd0;
    parameter [3:0] Conv1   =4'd1;
    parameter [3:0] Conv2   =4'd2;
    parameter [3:0] Conv3   =4'd3;
    parameter [3:0] Fc6     =4'd6;
    parameter [3:0] Fc7     =4'd7;

    parameter [3:0] Finish   =4'd8;
    parameter [3:0] StConv2  =4'd10;
    parameter [3:0] StConv3  =4'd11;
    parameter [3:0] StFc6    =4'd12;
    parameter [3:0] StFc7    =4'd13;


    //Conv 1
    reg c1start;
    reg next_c1start;
    wire c1finish;
    always @(posedge clk)begin
        if(!rst_n)begin
            c1start <= 0;
        end
        else begin
            c1start <= next_c1start;
        end
    end
    always @*begin
        if(state==Pre && compute_start==1'b1)begin
            next_c1start = 1;
        end
        else begin
            next_c1start = 0;
        end
    end
    wire [ 3:0] c1_weight_wea0;
    wire [ 3:0] c1_weight_wea1;
    wire [15:0] c1_weight_addr0;
    wire [15:0] c1_weight_addr1;
    wire [ 3:0] c1_act_wea0;
    wire [15:0] c1_act_addr0;
    wire [31:0] c1_act_wdata0;
    wire [ 3:0] c1_act_wea1;
    wire [15:0] c1_act_addr1;
    wire [31:0] c1_act_wdata1;

    conv1 c1(
        .clk(clk),
        .rst_n(rst_n),
        .start(c1start),
        .finish(c1finish),
    //weight
        .sc_CONV1(sc_CONV1),
        .weight_wea0(c1_weight_wea0),
        .weight_addr0(c1_weight_addr0),
        .weight_rdata0(weight_rdata0),
        .weight_wea1(c1_weight_wea1),
        .weight_addr1(c1_weight_addr1),
        .weight_rdata1(weight_rdata1),

    // Activation sram, dual port
        .act_wea0  (c1_act_wea0  ),
        .act_addr0 (c1_act_addr0 ),
        .act_wdata0(c1_act_wdata0),
        .act_rdata0(act_rdata0   ),
        .act_wea1  (c1_act_wea1  ),
        .act_addr1 (c1_act_addr1 ),
        .act_wdata1(c1_act_wdata1),
        .act_rdata1(act_rdata1   )
    );

//Conv 2
    reg c2start;
    reg next_c2start;
    wire c2finish;
    always @(posedge clk)begin
        if(!rst_n)begin
            c2start <= 0;
        end
        else begin
            c2start <= next_c2start;
        end
    end
    always @*begin
        if(state==StConv2 )begin
            next_c2start = 1;
        end
        else begin
            next_c2start = 0;
        end
    end
    wire [ 3:0] c2_weight_wea0;
    wire [ 3:0] c2_weight_wea1;
    wire [15:0] c2_weight_addr0;
    wire [15:0] c2_weight_addr1;
    wire [ 3:0] c2_act_wea0;
    wire [15:0] c2_act_addr0;
    wire [31:0] c2_act_wdata0;
    wire [ 3:0] c2_act_wea1;
    wire [15:0] c2_act_addr1;
    wire [31:0] c2_act_wdata1;

    conv2 c2(
        .clk(clk),
        .rst_n(rst_n),
        .start(c2start),
        .finish(c2finish),
    //weight
        .scale(sc_CONV2),
        .weight_wea0(c2_weight_wea0),
        .weight_addr0(c2_weight_addr0),
        .weight_rdata0(weight_rdata0),
        .weight_wea1(c2_weight_wea1),
        .weight_addr1(c2_weight_addr1),
        .weight_rdata1(weight_rdata1),

    // Activation sram, dual port
        .act_wea0  (c2_act_wea0  ),
        .act_addr0 (c2_act_addr0 ),
        .act_wdata0(c2_act_wdata0),
        .act_rdata0(act_rdata0   ),
        .act_wea1  (c2_act_wea1  ),
        .act_addr1 (c2_act_addr1 ),
        .act_wdata1(c2_act_wdata1),
        .act_rdata1(act_rdata1   )
    );


    //conv3
    reg c3start;
    reg next_c3start;
    wire c3finish;
    always @(posedge clk)begin
        if(!rst_n)begin
            c3start <= 0;
        end
        else begin
            c3start <= next_c3start;
        end
    end
    always @*begin
        if(state==StConv3 )begin
            next_c3start = 1;
        end
        else begin
            next_c3start = 0;
        end
    end
    wire [ 3:0] c3_weight_wea0;
    wire [ 3:0] c3_weight_wea1;
    wire [15:0] c3_weight_addr0;
    wire [15:0] c3_weight_addr1;
    wire [ 3:0] c3_act_wea0;
    wire [15:0] c3_act_addr0;
    wire [31:0] c3_act_wdata0;
    wire [ 3:0] c3_act_wea1;
    wire [15:0] c3_act_addr1;
    wire [31:0] c3_act_wdata1;

    conv3 c3(
        .clk(clk),
        .rst_n(rst_n),
        .start(c3start),
        .finish(c3finish),
    //weight
        .scale(sc_CONV3),
        .weight_wea0(c3_weight_wea0),
        .weight_addr0(c3_weight_addr0),
        .weight_rdata0(weight_rdata0),
        .weight_wea1(c3_weight_wea1),
        .weight_addr1(c3_weight_addr1),
        .weight_rdata1(weight_rdata1),

    // Activation sram, dual port
        .act_wea0  (c3_act_wea0  ),
        .act_addr0 (c3_act_addr0 ),
        .act_wdata0(c3_act_wdata0),
        .act_rdata0(act_rdata0   ),
        .act_wea1  (c3_act_wea1  ),
        .act_addr1 (c3_act_addr1 ),
        .act_wdata1(c3_act_wdata1),
        .act_rdata1(act_rdata1   )
    );
//Fully Cnnected 6
    reg f6start;
    reg next_f6start;
    wire f6finish;
    always @(posedge clk)begin
        if(!rst_n)begin
            f6start <= 0;
        end
        else begin
            f6start <= next_f6start;
        end
    end
    always @*begin
        if(state==StFc6 )begin
            next_f6start = 1;
        end
        else begin
            next_f6start = 0;
        end
    end
    wire [ 3:0] f6_weight_wea0;
    wire [ 3:0] f6_weight_wea1;
    wire [15:0] f6_weight_addr0;
    wire [15:0] f6_weight_addr1;
    wire [ 3:0] f6_act_wea0;
    wire [15:0] f6_act_addr0;
    wire [31:0] f6_act_wdata0;
    wire [ 3:0] f6_act_wea1;
    wire [15:0] f6_act_addr1;
    wire [31:0] f6_act_wdata1;

    fc6 f6(
        .clk(clk),
        .rst_n(rst_n),
        .start(f6start),
        .finish(f6finish),
    //weight
        .scale(sc_FC1),
        .weight_wea0(f6_weight_wea0),
        .weight_addr0(f6_weight_addr0),
        .weight_rdata0(weight_rdata0),
        .weight_wea1(f6_weight_wea1),
        .weight_addr1(f6_weight_addr1),
        .weight_rdata1(weight_rdata1),

    // Activation sram, dual port
        .act_wea0  (f6_act_wea0  ),
        .act_addr0 (f6_act_addr0 ),
        .act_wdata0(f6_act_wdata0),
        .act_rdata0(act_rdata0   ),
        .act_wea1  (f6_act_wea1  ),
        .act_addr1 (f6_act_addr1 ),
        .act_wdata1(f6_act_wdata1),
        .act_rdata1(act_rdata1   )
    );

//Fully Cnnected 7
    reg f7start;
    reg next_f7start;
    wire f7finish;
    always @(posedge clk)begin
        if(!rst_n)begin
            f7start <= 0;
        end
        else begin
            f7start <= next_f7start;
        end
    end
    always @*begin
        if(state==StFc7 )begin
            next_f7start = 1;
        end
        else begin
            next_f7start = 0;
        end
    end
    wire [ 3:0] f7_weight_wea0;
    wire [ 3:0] f7_weight_wea1;
    wire [15:0] f7_weight_addr0;
    wire [15:0] f7_weight_addr1;
    wire [ 3:0] f7_act_wea0;
    wire [15:0] f7_act_addr0;
    wire [31:0] f7_act_wdata0;
    wire [ 3:0] f7_act_wea1;
    wire [15:0] f7_act_addr1;
    wire [31:0] f7_act_wdata1;

    fc7 f7(
        .clk(clk),
        .rst_n(rst_n),
        .start(f7start),
        .finish(f7finish),
    //weight
        .scale(sc_FC2),
        .weight_wea0(f7_weight_wea0),
        .weight_addr0(f7_weight_addr0),
        .weight_rdata0(weight_rdata0),
        .weight_wea1(f7_weight_wea1),
        .weight_addr1(f7_weight_addr1),
        .weight_rdata1(weight_rdata1),

    // Activation sram, dual port
        .act_wea0  (f7_act_wea0  ),
        .act_addr0 (f7_act_addr0 ),
        .act_wdata0(f7_act_wdata0),
        .act_rdata0(act_rdata0   ),
        .act_wea1  (f7_act_wea1  ),
        .act_addr1 (f7_act_addr1 ),
        .act_wdata1(f7_act_wdata1),
        .act_rdata1(act_rdata1   )
    );

    always@(posedge clk) begin
        if(!rst_n) begin
            state <= Pre;
        end
        else begin
            state <= next_state;
        end
    end
    always@(*)begin
        case(state)
            Pre:begin

                weight_wea0  = 0;
                weight_addr0 = 0;
                weight_wea1  = 0;
                weight_addr1 = 0;
                weight_wdata0 = 0;
                weight_wdata1 = 0;
                act_wea0     = 0;
                act_addr0    = 0;
                act_wdata0   = 0;
                act_wea1     = 0;
                act_addr1    = 0;
                act_wdata1   = 0;
                if(compute_start==1'b1)begin
                    next_state=Conv1;
                end
                else begin
                    next_state=Pre;
                end
                compute_finish=0;
            end
            Conv1:begin
                weight_wea0 = c1_weight_wea0;
                weight_addr0 = c1_weight_addr0;
                weight_wea1 = c1_weight_wea1;
                weight_addr1 = c1_weight_addr1;
                weight_wdata0 = 0;
                weight_wdata1 = 0;
                act_wea0 = c1_act_wea0;
                act_addr0 = c1_act_addr0;
                act_wdata0 = c1_act_wdata0;
                act_wea1 = c1_act_wea1;
                act_addr1 = c1_act_addr1;
                act_wdata1 = c1_act_wdata1;
                if(c1finish==1)begin
                    next_state=StConv2;
                    //next_state=Finish;
                end
                else begin
                    next_state=Conv1;
                end
                compute_finish=0;
            end
            
            StConv2:begin
                weight_wea0  = 0;
                weight_addr0 = 0;
                weight_wea1  = 0;
                weight_addr1 = 0;
                weight_wdata0 = 0;
                weight_wdata1 = 0;
                act_wea0     = 0;
                act_addr0    = 0;
                act_wdata0   = 0;
                act_wea1     = 0;
                act_addr1    = 0;
                act_wdata1   = 0;
                next_state=Conv2;
                compute_finish=0;
            end
            Conv2:begin
                weight_wea0  = c2_weight_wea0;
                weight_addr0 = c2_weight_addr0;
                weight_wea1  = c2_weight_wea1;
                weight_addr1 = c2_weight_addr1;
                weight_wdata0 = 0;
                weight_wdata1 = 0;
                act_wea0     = c2_act_wea0;
                act_addr0    = c2_act_addr0;
                act_wdata0   = c2_act_wdata0;
                act_wea1     = c2_act_wea1;
                act_addr1    = c2_act_addr1;
                act_wdata1   = c2_act_wdata1;
                if(c2finish==1)begin
                    next_state=StConv3;
                end
                else begin
                    next_state=Conv2;
                end
                compute_finish=0;
            end
            StConv3:begin
                weight_wea0  = 0;
                weight_addr0 = 0;
                weight_wea1  = 0;
                weight_addr1 = 0;
                weight_wdata0 = 0;
                weight_wdata1 = 0;
                act_wea0     = 0;
                act_addr0    = 0;
                act_wdata0   = 0;
                act_wea1     = 0;
                act_addr1    = 0;
                act_wdata1   = 0;
                next_state=Conv3;
                compute_finish=0;
            end
            Conv3:begin
                weight_wea0  = c3_weight_wea0;
                weight_addr0 = c3_weight_addr0;
                weight_wea1  = c3_weight_wea1;
                weight_addr1 = c3_weight_addr1;
                weight_wdata0 = 0;
                weight_wdata1 = 0;
                act_wea0     = c3_act_wea0;
                act_addr0    = c3_act_addr0;
                act_wdata0   = c3_act_wdata0;
                act_wea1     = c3_act_wea1;
                act_addr1    = c3_act_addr1;
                act_wdata1   = c3_act_wdata1;
                if(c3finish==1)begin
                    next_state=StFc6;
                end
                else begin
                    next_state=Conv3;
                end
                compute_finish=0;
            end
            StFc6:begin
                weight_wea0  = 0;
                weight_addr0 = 0;
                weight_wea1  = 0;
                weight_addr1 = 0;
                weight_wdata0 = 0;
                weight_wdata1 = 0;
                act_wea0     = 0;
                act_addr0    = 0;
                act_wdata0   = 0;
                act_wea1     = 0;
                act_addr1    = 0;
                act_wdata1   = 0;
                next_state=Fc6;
                compute_finish=0;
            end
            Fc6:begin
                weight_wea0  = f6_weight_wea0;
                weight_addr0 = f6_weight_addr0;
                weight_wea1  = f6_weight_wea1;
                weight_addr1 = f6_weight_addr1;
                weight_wdata0 = 0;
                weight_wdata1 = 0;
                act_wea0     = f6_act_wea0;
                act_addr0    = f6_act_addr0;
                act_wdata0   = f6_act_wdata0;
                act_wea1     = f6_act_wea1;
                act_addr1    = f6_act_addr1;
                act_wdata1   = f6_act_wdata1;
                if(f6finish==1)begin
                    next_state=StFc7;
                end
                else begin
                    next_state=Fc6;
                end
                compute_finish=0;
            end
            StFc7:begin
                weight_wea0  = 0;
                weight_addr0 = 0;
                weight_wea1  = 0;
                weight_addr1 = 0;
                weight_wdata0 = 0;
                weight_wdata1 = 0;
                act_wea0     = 0;
                act_addr0    = 0;
                act_wdata0   = 0;
                act_wea1     = 0;
                act_addr1    = 0;
                act_wdata1   = 0;
                next_state=Fc7;
                compute_finish=0;
            end
            Fc7:begin
                weight_wea0  = f7_weight_wea0;
                weight_addr0 = f7_weight_addr0;
                weight_wea1  = f7_weight_wea1;
                weight_addr1 = f7_weight_addr1;
                weight_wdata0 = 0;
                weight_wdata1 = 0;
                act_wea0     = f7_act_wea0;
                act_addr0    = f7_act_addr0;
                act_wdata0   = f7_act_wdata0;
                act_wea1     = f7_act_wea1;
                act_addr1    = f7_act_addr1;
                act_wdata1   = f7_act_wdata1;
                if(f7finish==1)begin
                    next_state=Finish;
                end
                else begin
                    next_state=Fc7;
                end
                compute_finish=0;
            end
            Finish:begin
                weight_wea0  = 0;
                weight_addr0 = 0;
                weight_wea1  = 0;
                weight_addr1 = 0;
                weight_wdata0 = 0;
                weight_wdata1 = 0;
                act_wea0     = 0;
                act_addr0    = 0;
                act_wdata0   = 0;
                act_wea1     = 0;
                act_addr1    = 0;
                act_wdata1   = 0;
                compute_finish=1;
                next_state=Finish;
            end
            default begin
                weight_wea0  = 0;
                weight_addr0 = 0;
                weight_wea1  = 0;
                weight_addr1 = 0;
                weight_wdata0 = 0;
                weight_wdata1 = 0;
                act_wea0     = 0;
                act_addr0    = 0;
                act_wdata0   = 0;
                act_wea1     = 0;
                act_addr1    = 0;
                act_wdata1   = 0;
                next_state=Pre;
                compute_finish=0;
            end
        endcase
    end
    
endmodule

