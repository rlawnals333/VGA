`timescale 1ns / 1ps

module frame_buffer (
    input  wire        reset,     // Active‐High 비동기 리셋
    // write side
    input  wire        wclk,      // OV7670 PCLK
    input  wire        we,
    input  wire [14:0] wAddr,
    input  wire [15:0] wData,
    // read side
    input  wire        rclk,      // 읽기 클럭(=VGA 클럭)
    input  wire        oe,        // 읽기 이네이블
    input  wire [14:0] rAddr,
    output reg  [15:0] rData,     // 읽어온 데이터
    //
    output reg         frame_done // 한 프레임 쓰기 완료 플래그
);

    // 160*120 = 19200 픽셀, 각 픽셀당 8비트(GRAY8)
    (* ram_style = "block" *) reg [15:0] mem [0:160*120-1];

    //========================================================
    // 1) 쓰기 포트 (비동기 리셋 + posedge wclk)
    //========================================================
    always_ff @(posedge wclk or posedge reset) begin
        if (reset) begin
            frame_done <= 1'b0;
        end else begin
            // 마지막 주소에 쓰기 이네이블이 걸리면 frame_done=1
            if (we && wAddr == (160*120 - 1))
                frame_done <= 1'b1;
            else
                frame_done <= 1'b0;
        end
    end

    always_ff @( posedge wclk ) begin
        if (we) begin
            mem[wAddr] <= wData;
        end
    end

    //========================================================
    // 2) 읽기 포트 (비동기 리셋 + posedge rclk)
    //========================================================
    always_ff @(posedge rclk or posedge reset) begin
        if (reset) begin
            rData <= 16'd0;
        end else if (oe) begin
            rData <= mem[rAddr];
        end else begin
            rData <= rData;  // 읽기 이네이블이 없으면 그대로 유지
        end
    end

endmodule
