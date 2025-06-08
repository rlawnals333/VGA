`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/28 14:34:43
// Design Name: 
// Module Name: vga_rgb_switch
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


module vga_rgb(

    input logic [9:0] x_pixel,
    input logic [9:0] y_pixel,
    input logic DE,
    output logic [3:0] red_port,
    output logic [3:0] green_port,
    output logic [3:0] blue_port
    );

    always_comb begin // 조합회로로 유지하는법은 비교문 쓰는거임 
        red_port = 0;
        green_port = 0;
        blue_port = 0;
    if(!DE) begin
        red_port = 0;
        green_port = 0;
        blue_port = 0;
    end
    else begin
        if((y_pixel >= 0) && (y_pixel < 320)) begin
            if((x_pixel >= 0) && (x_pixel <90) ) begin
                red_port = 4'hF;
                green_port = 4'hf;
                blue_port = 4'hf;
            end
             else if((x_pixel >= 90) && (x_pixel <180) ) begin
                red_port = 4'hF;
                green_port = 4'hF ;
                blue_port = 0;
            end
             else if((x_pixel >= 180) && (x_pixel <270) ) begin
                red_port = 0;
                green_port = 4'hF ;
                blue_port = 4'hF;
            end
            else if((x_pixel >= 270) && (x_pixel <360) ) begin
                red_port = 0;
                green_port = 4'hF;
                blue_port = 0;
            end
            else if((x_pixel >= 360) && (x_pixel <450) ) begin
                red_port = 4'hF;
                green_port = 0 ;
                blue_port = 4'hF;
            end
            else if((x_pixel >= 450) && (x_pixel <540) ) begin
                red_port = 24'hF;
                green_port = 0;
                blue_port = 0;
            end
            else begin
                red_port = 0;
                green_port = 0 ;
                blue_port = 4'hF;
            end

        end
        else if((y_pixel >= 320) && (y_pixel < 360)) begin
            if((x_pixel >= 0) && (x_pixel <90) ) begin
                red_port = 0;
                green_port = 0;
                blue_port = 4'hF;
            end
             else if((x_pixel >= 90) && (x_pixel <180) ) begin
                red_port = 0;
                green_port = 0;
                blue_port = 0;
            end
             else if((x_pixel >= 180) && (x_pixel <270) ) begin
                red_port = 4'hF;
                green_port = 0 ;
                blue_port = 4'hF;
            end
            else if((x_pixel >= 270) && (x_pixel <360) ) begin
                red_port = 0;
                green_port = 0;
                blue_port = 0;
            end
            else if((x_pixel >= 360) && (x_pixel <450) ) begin
                red_port = 0;
                green_port = 4'hF ;
                blue_port = 4'hF;
            end
            else if((x_pixel >= 450) && (x_pixel <540) ) begin
                red_port =0;
                green_port = 0;
                blue_port = 0;
            end
            else begin
                red_port = 4'hF;
                green_port = 4'hF ;
                blue_port = 4'hF;
            end
        end

        else begin
                if((x_pixel >= 0) && (x_pixel <105) ) begin
                red_port = 2;
                green_port = 0;
                blue_port = 6;
            end
             else if((x_pixel >= 105) && (x_pixel <210) ) begin
                red_port = 4'hF;
                green_port = 4'hF;
                blue_port = 4'hF;
            end
             else if((x_pixel >= 210) && (x_pixel <315) ) begin
                red_port = 8;
                green_port = 0;
                blue_port = 8;
            end
            else  begin
                red_port = 0;
                green_port = 0 ;
                blue_port = 0;
            end
        
    end
    end
    end
endmodule
