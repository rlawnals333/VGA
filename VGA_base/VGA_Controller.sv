`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/28 12:36:25
// Design Name: 
// Module Name: VGA_Controller
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


module VGA_Controller(
    input logic clk,
    input logic reset,
    output logic h_sync,
    output logic v_sync,
    output logic [3:0] red_port,
    output logic [3:0] green_port,
    output logic [3:0] blue_port
    );
// logic DE;
logic [9:0] x_pixel, y_pixel;
logic DE;
 VGA_DECODER u_vga_decoder(.*);

 vga_rgb u_rgb(.*);
endmodule

module VGA_DECODER(
    input logic clk,
    input logic reset,
    output logic h_sync,
    output logic v_sync,
    output logic [9:0] x_pixel,
    output logic [9:0] y_pixel,
    output logic DE
);
logic pclk;
logic [9:0] h_counter, v_counter;

pixel_clk_gen u_pixel_clk_gen (
    .clk(clk),
    .reset(reset),
    .pclk(pclk)
);


pixel_counter U_pixel_counter(
    .pclk(pclk),
    .reset(reset),
    .h_counter(h_counter),
    .v_counter(v_counter)
);

vga_decoder u_decoder (
    .h_counter(h_counter),
    .v_counter(v_counter),
    
    .DE(DE),
    .x_pixel(x_pixel),
    .y_pixel(y_pixel),
    .h_sync(h_sync),
    .v_sync(v_sync)
);

endmodule
module pixel_clk_gen  (
    input logic clk,
    input logic reset,
    output logic pclk
);
    logic [1:0] p_count;
    always_ff @( posedge clk, posedge reset ) begin 
        if(reset) begin
            pclk <= 0;
            p_count <=0;
        end        
        else begin
            if(p_count == 3) begin
                p_count <= 0;
                pclk <= 1'b1;
            end
            else begin
                p_count <= p_count + 1;
                pclk <= 0;
            end

        end
    end
endmodule

module pixel_counter (
    input logic pclk,
    input logic reset,
    output logic [9:0] h_counter,
    output logic [9:0] v_counter
);

    always_ff@(posedge pclk, posedge reset) begin
        if(reset) begin
            h_counter <= 0;
            v_counter <= 0;
        end
        else begin
            if(h_counter == 799) begin  //if 문은 순간포착이기 때문에 clk posedge가 trigger니까 잘생각하셈
                if(v_counter == 524) begin
                        v_counter <= 0;
                        h_counter <= 0;
                    end
                else begin
                    v_counter <= v_counter + 1;
                    h_counter <= 0;
                end
                
            end
            else begin
                h_counter <= h_counter + 1;
            end
        end
    end
    
endmodule

module vga_decoder (
    input logic [9:0] h_counter,
    input logic [9:0] v_counter,
    
    output logic DE,
    output logic [9:0] x_pixel,
    output logic [9:0] y_pixel,
    output logic h_sync,
    output logic v_sync
);
localparam  H_Visible_area =   640;  
localparam  H_Front_porch  =   16;
localparam  H_Sync_pulse   =   96; 
localparam  H_Back_porch   =   48; 
localparam  H_Whole_line   =   800; 
 
 
localparam V_Visible_area  =  480;
localparam V_Front_porch   =  10;
localparam V_Sync_pulse    =  2;
localparam V_Back_porch    =  33; 
localparam V_Whole_frame   =  525;

assign x_pixel = (DE) ? h_counter : 10'bz; // 끊어버리기 
assign y_pixel = (DE) ? v_counter : 10'bz;

assign h_sync = !((h_counter >= (H_Visible_area + H_Front_porch)) && (h_counter < (H_Visible_area + H_Front_porch + H_Sync_pulse)));
assign v_sync = !((v_counter >= (V_Visible_area + V_Front_porch)) && (v_counter < (V_Visible_area + V_Front_porch + V_Sync_pulse)));
assign DE = (h_counter < H_Visible_area) && (v_counter < V_Visible_area);  // assign이 타이밍 측면에서 훨씬 좋음 
//비교기 있어서 latch 불필요
// always_comb begin  // delay 발생 
//     DE = 1'b1;
//     h_sync = 1'b1;
//     v_sync = 1'b1;
//     if(h_counter >= H_Visible_area) begin
//         DE = 0;
//         if(h_counter < H_Visible_area + H_Front_porch + H_Sync_pulse) begin
//             h_sync = 0;
//         end
//     end
//     if(v_counter >= V_Visible_area) begin
//         DE = 0;
//         if(v_counter < V_Visible_area + V_Front_porch + V_Sync_pulse) begin
//             v_sync = 0;
//         end
//     end
// end
// retrace 구간 만들어주기
    
endmodule