`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/03 17:31:09
// Design Name: 
// Module Name: tick_gen
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


module tick_gen#(parameter FCOUNT = 100_000, BIT_SIZE = $clog2(FCOUNT))(
    input logic clk,
    input logic reset,

    output logic tick
    );

    logic [BIT_SIZE-1 :0] c_count, n_count;
    logic c_tick, n_tick;

    assign tick = c_tick;

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            c_count <=0;
            c_tick <=0;
        end

        else begin
            c_count <= n_count;
            c_tick <= n_tick;
        end
    end

    always @(*) begin // 조합회로는 매클럭마다 발생하므로  모든 input이 변화하면 반응하므로 기본적으로 clk 마다 이벤트 발생 
        n_count = c_count;
        n_tick = 0;
        if(c_count == FCOUNT -1) begin
            n_count = 0;
            n_tick = 1'b1;
        end
        else begin
            n_count = c_count + 1;
        end
    end
endmodule

// module tick_gen_adv#(parameter FCOUNT = 100_000, BIT_SIZE = $clog2(FCOUNT))(
//     input clk,
//     input reset,
//     input clear,
//     input run_stop,
 

//     output tick
//     );

//     reg [BIT_SIZE-1 :0] c_count, n_count;
//     reg c_tick, n_tick;

//     assign tick = c_tick;

//     always @(posedge clk, posedge reset) begin
//         if(reset) begin
//             c_count <=0;
//             c_tick <=0;
//         end

//         else begin
//             c_count <= n_count;
//             c_tick <= n_tick;
//         end
//     end

//     always @(*) begin // 조합회로는 매클럭마다 발생하므로  모든 input이 변화하면 반응하므로 기본적으로 clk 마다 이벤트 발생 
//         n_count = c_count;
//         n_tick = 0;
     
//             if(clear || (run_stop == 0)) n_count = 0;
//             else begin
//                 if(c_count == FCOUNT -1) begin
//                     n_count = 0;
//                     n_tick = 1'b1;
//                 end
//                 else begin
//                     n_count = c_count + 1;
//                 end
//             end
       
//     end
// endmodule

