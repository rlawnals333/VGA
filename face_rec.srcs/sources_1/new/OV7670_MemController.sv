`timescale 1ns / 1ps

module OV7670_MemController (
    input  logic        pclk,
    input  logic        reset,
    input  logic        href,
    input  logic        v_sync,
    input  logic [ 7:0] ov7670_data,
    output logic        we,
    output logic [14:0] wAddr,
    output logic [15:0] wData
);

    logic [ 9:0] h_counter;  // 320 * 2 = 640 (320 pixel)
    logic [ 7:0] v_counter;  // 240 * 2 = 480 (240 line)
    logic [15:0] pix_data;

    logic [ 8:0]  h_qvga = h_counter[9:1];  // 0..319
    logic [ 7:0]  v_qvga = v_counter;       // 0..239

    logic [ 7:0]  h_qqvga = h_qvga[8:1];  // 0..159
    logic [ 6:0]  v_qqvga = v_qvga[7:1];  // 0..119

    // assign wAddr = v_counter * 320 + h_counter[9:1]; <- QVGA용

    assign wAddr = v_qqvga * 160 + h_qqvga;
    assign wData = pix_data;

    always_ff @(posedge pclk, posedge reset) begin : h_sequence
        if (reset) begin
            pix_data  <= 0;
            h_counter <= 0;
            we        <= 1'b0;
        end else begin
            if (href == 1'b0) begin
                h_counter <= 0;
                we        <= 1'b0;
            end else begin
                h_counter <= h_counter + 1;
                if ((h_counter[0] == 1'b1) && (h_qvga[0] == 1'b1)) begin // odd data
                    pix_data[7:0] <= ov7670_data;
                    we            <= 1'b1;
                end else begin // even data
                    we <= 1'b0;
                    if (h_counter[0] == 1'b0) begin
                        pix_data[15:8] <= ov7670_data;
                    end
                end
            end
        end
    end

    always_ff @(posedge pclk, posedge reset) begin : v_sequence
        if (reset) begin
            v_counter <= 0;
        end else begin
            if (v_sync) begin
                v_counter <= 0;
            end else begin
                if (h_counter == 640 - 1) begin
                    v_counter <= v_counter + 1;
                end
            end
        end
    end


endmodule
