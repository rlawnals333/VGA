`timescale 1ns / 1ps



module QVGA_MemController (
    input  logic        clk,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic        DE,
    output logic        rclk,
    output logic        d_en,
    output logic [16:0] rAddr,
    input  logic [15:0] rData,
    output logic [ 3:0] red_port,
    output logic [ 3:0] green_port,
    output logic [ 3:0] blue_port
);

    logic display_en;

    assign rclk = clk;
    assign display_en = (x_pixel < 160 && y_pixel < 120);
    assign d_en = display_en;
    assign rAddr = display_en ? (y_pixel * 160 + x_pixel) : 0;

    logic [3:0] R_port_base, G_port_base, B_port_base;
    assign {R_port_base, G_port_base, B_port_base} = display_en ?
        {rData[15:12], rData[10:7], rData[4:1]} : 12'b0;

    logic [7:0] char_bitmap;
    logic [7:0] char_code;
    logic [2:0] font_row, font_col;
    logic text_on;

    assign font_row = y_pixel[2:0];
    assign font_col = x_pixel[2:0];

    logic [23:0] blink_counter;
    logic blink_on;

    always_ff @(posedge clk)
        blink_counter <= blink_counter + 1;

    assign blink_on = blink_counter[23];
    logic draw_text;
    assign draw_text = (y_pixel < 8);  // 상단 8줄에만 텍스트 표시

    always_comb begin
        char_code = 7'd0;
        if (y_pixel < 8) begin
            case (x_pixel >> 3)
                0: char_code = "R";
                1: char_code = "E";
                2: char_code = "C";
                default: char_code = 7'd0;
            endcase
        end
    end

    FontROM fontrom_inst (
        .char_code(char_code),
        .row(font_row),
        .row_data(char_bitmap)
    );

    assign text_on = draw_text && blink_on && char_bitmap[7 - font_col];
    assign red_port   = text_on ? 4'hF : R_port_base;
    assign green_port = text_on ? 4'h0 : G_port_base;
    assign blue_port  = text_on ? 4'h0 : B_port_base;

endmodule


module FontROM (
    input  logic [6:0] char_code,
    input  logic [2:0] row,
    output logic [7:0] row_data
);
    always_comb begin
        case ({char_code, row})
            {7'd82, 3'd0} : row_data = 8'b01111100;  // 'R'
            {7'd82, 3'd1} : row_data = 8'b01000010;
            {7'd82, 3'd2} : row_data = 8'b01000010;
            {7'd82, 3'd3} : row_data = 8'b01111100;
            {7'd82, 3'd4} : row_data = 8'b01010000;
            {7'd82, 3'd5} : row_data = 8'b01001000;
            {7'd82, 3'd6} : row_data = 8'b01000100;
            {7'd82, 3'd7} : row_data = 8'b00000000;

            {7'd69, 3'd0} : row_data = 8'b01111110;  // 'E'
            {7'd69, 3'd1} : row_data = 8'b01000000;
            {7'd69, 3'd2} : row_data = 8'b01000000;
            {7'd69, 3'd3} : row_data = 8'b01111100;
            {7'd69, 3'd4} : row_data = 8'b01000000;
            {7'd69, 3'd5} : row_data = 8'b01000000;
            {7'd69, 3'd6} : row_data = 8'b01111110;
            {7'd69, 3'd7} : row_data = 8'b00000000;

            {7'd67, 3'd0} : row_data = 8'b00111100;  // 'C'
            {7'd67, 3'd1} : row_data = 8'b01000010;
            {7'd67, 3'd2} : row_data = 8'b01000000;
            {7'd67, 3'd3} : row_data = 8'b01000000;
            {7'd67, 3'd4} : row_data = 8'b01000000;
            {7'd67, 3'd5} : row_data = 8'b01000010;
            {7'd67, 3'd6} : row_data = 8'b00111100;
            {7'd67, 3'd7} : row_data = 8'b00000000;

    

            default: row_data = 8'b00000000;
        endcase
    end
endmodule

