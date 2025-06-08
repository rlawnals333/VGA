`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/25 10:20:29
// Design Name: 
// Module Name: us_control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//start 하자마자 소닉 모듈에서 발사 => 신호 들어오면 시간 start_trigger 부터 sr04로부터 들어온시간 계산 
// fsm 식으로 ㄱㄱㄱ
//최대 340m까지 가능능
module us_control 
#(parameter TICK_COUNT = 400*58, TICK_BIT_SIZE = $clog2(TICK_COUNT), 
            DISTANCE_RANGE = 400, DIS_BIT_SIZE = ($clog2(DISTANCE_RANGE)) ) // 거리 cm 단위 
(
    input logic clk,
    input logic reset,
    input logic SR04_data,
    input logic start,
    // input logic [2:0] sw_mode,

    output logic start_trigger,
    output logic [8:0]distance,
    output logic measure_done
    // output logic is_measure
   
    

    );
    localparam IDLE = 0, SEND = 1,START = 2, MEASURE = 3 , STOP = 4;
    logic [2:0] current_state, next_state;
    logic c_trigger, n_trigger; 
    logic [8:0] c_distance,n_distance;  // 개수 몇개? 
    logic [TICK_BIT_SIZE-1 : 0] c_tick_count, n_tick_count;
    logic c_done, n_done;
    logic n_echo;
    logic measuring;

    // logic w_btn_start;

    // assign w_btn_start = (btn_start) & (sw_mode == 3'b100); 

    // assign measuring = ((SR04_data == 1'b1)&&(n_echo == 1'b0)) ? 1'b1 : 1'b0;
          

    // assign is_measure = (current_state == MEASURE) ? 1'b1 : 1'b0;
    logic us_tick;

    assign start_trigger = c_trigger;
    assign distance = (c_distance <400) ? c_distance : 400;
    assign measure_done = c_done;
   

  us_tick_gen u_us_tick_gen ( 
    .clk(clk),
    .reset(reset),

     .tick(us_tick)

);

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            current_state <= IDLE;
            c_trigger <= 0;
            c_distance <= 0;
            c_tick_count <= 0;
            c_done <= 0;
            n_echo <= 0;
            
        end
        else begin
            current_state <= next_state;
            c_trigger <= n_trigger;
            c_distance <= n_distance;
            c_tick_count <= n_tick_count;
            c_done <= n_done;
            n_echo <= SR04_data;
        end
    end

    always @(*) begin
        next_state = current_state;
        n_trigger = c_trigger;
        n_distance = c_distance;
        n_tick_count = c_tick_count;
        n_done = 0;
    

        case (current_state)
         IDLE: begin
            if(start) begin
                next_state = SEND;
                
            end
         end
        SEND: begin if(us_tick) begin
            n_trigger = 1'b1;
            n_tick_count = 0;
            next_state = START;
        end
        end

        START: begin
                  if(us_tick) begin
                    if(c_tick_count == 9) begin
                            n_trigger = 0;
                            n_tick_count = 0;
                            next_state = MEASURE;
                            // 타이밍 어케할까? 
                        end
                        else begin
                            n_tick_count = c_tick_count + 1;
                            n_trigger = c_trigger;
                            
                        end
                end
        end

        MEASURE: begin

            if((SR04_data == 0) && (n_echo == 1'b1)) begin
            
                next_state = STOP;
                n_distance = c_tick_count / 58;
                // n_done = 1'b1;
            end
    
            
            else if(SR04_data == 1'b1) begin
                if(us_tick) begin
                    n_tick_count = c_tick_count + 1;
                end
                else begin
                    n_tick_count = c_tick_count;
                end
            end

    // 너무 오래걸리면 끄기 최대 거리임 

            else begin
                if (us_tick) begin
                    if(c_tick_count > 500*58) begin
                            n_tick_count = 0;
                            next_state = IDLE;
                            // measure_done = 1'b1;
                            // 타이밍 어케할까? 
                        end
                        else begin
                            n_tick_count = c_tick_count + 1;
                            
                        end
                end
             end
        end

        STOP: begin
            next_state = IDLE;
            n_done = 1'b1;
        end
        endcase
    end


endmodule

    

module us_tick_gen ( 
    input logic clk,
    input logic reset,

    output logic tick

);
    parameter COUNT = 100, BIT_SIZE = $clog2(COUNT);
    logic c_tick, n_tick;
    logic [BIT_SIZE-1:0] c_count, n_count;

    assign tick = c_tick;

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            c_tick <= 0;
            c_count <= 0;
        end

        else begin
            c_tick <= n_tick;
            c_count <= n_count;
        end
    end

    always @(*) begin
        n_tick = 0; // 10us 유지 tick 
        n_count = c_count;

        if(c_count == COUNT-1) begin
            n_tick = 1;
            n_count = 0;
        end

        else begin
            n_count = c_count + 1;
            n_tick = 0;
        end
    end

endmodule