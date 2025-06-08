`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/03 18:16:52
// Design Name: 
// Module Name: uart_top
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



module uart_rx (
    input logic clk,
    input logic reset,
    input logic rx_in,


    output logic [7:0] rx_out,
    output logic rx_busy,
    output logic rx_done
);

    logic [2:0] current_state, next_state;
    logic [7:0] c_rx, n_rx;
    logic [4:0] c_count, n_count;
    logic [2:0] c_bit_count, n_bit_count;
    logic c_done, n_done;
    logic c_busy, n_busy;
    logic baud_tick;

    assign rx_out = c_rx;
    assign rx_busy = c_busy;
    assign rx_done = c_done;

    //ouput assign 
    localparam IDLE = 0, SEND = 1, START = 2, DATA =3, STOP = 4 ;

    tick_gen#(.FCOUNT(10000_0000 / (921600 * 16))) tick_baudrate( // oversampling 16 
    .clk(clk),
    .reset(reset),

    .tick(baud_tick)
    );

    always @(posedge clk, posedge reset) begin
        
        if(reset) begin
            current_state <= 0;
            c_rx <= 0;
            c_count <= 0;
            c_bit_count <= 0;
            c_done <= 0;
            c_busy <= 0;
        end

        else begin
            current_state <= next_state;
            c_rx <= n_rx;
            c_count <= n_count;
            c_bit_count <= n_bit_count; // fsm 식으로 가야되
            c_done <= n_done;
            c_busy <= n_busy;
        end

    end

    always @(*) begin
        next_state = current_state;
        n_rx = c_rx;
        n_count = c_count;
        n_bit_count = c_bit_count;
        n_done = 0;  // tick 
        n_busy = c_busy; // 유지


        case(current_state) // case문은 begin이 없음 
        IDLE : begin
            n_count = 0;
            n_bit_count = 0;
            if(rx_in == 0) begin
                next_state = SEND; // tick 사용하면 무조건 send 이래야 일정한 pulse 유지 가능
            end
        end
        
        SEND: begin
            if(baud_tick) next_state = START; 
            n_busy = 1'b1;
        end

        START: begin
            if(baud_tick) begin
                if(c_count == 7) begin
                    next_state = DATA;
                    n_count = 0;  //count 초기화 해줘야함 무조건 state 넘어갈 때 
                end

                else begin
                    n_count = c_count + 1;
                end
            end
        end

        DATA: begin
            
            if(baud_tick) begin
                if(c_bit_count == 7) begin  // 탈출조건 먼저 
                    if(c_count == 15) begin

                        n_rx = {rx_in,c_rx[7:1]};  // 저장 shift register / lsb 부터  // 앞에서 들어와야함 => 생각잘하셈 
                        next_state = STOP;
                        n_bit_count = 0;
                        n_count = 0;
                        
                    end

                    else begin
                        n_count = c_count + 1;
                    end
                end

                else begin // 탈출조건 아닐때 
                    if(c_count == 15) begin
                        n_rx = {rx_in,c_rx[7:1]};
                        n_count = 0;
                        n_bit_count = c_bit_count + 1;
                        
                    end
                    else begin
                        n_count = c_count + 1;
                    end
                end
            end
        end

        STOP: begin
            if(baud_tick) begin
                if(c_count == 23) begin
                    next_state = IDLE;
                    n_done = 1'b1;
                    n_busy = 0;
                end

                else begin
                    n_count = c_count + 1;
                end
            end
        end

        endcase
    end
endmodule