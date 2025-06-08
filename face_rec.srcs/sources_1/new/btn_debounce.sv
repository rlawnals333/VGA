`timescale 1ns / 1ps

module button_debounce_edge (
    input  logic clk,       // 100 MHz
    input  logic reset,     // Active‐High 리셋
    input  logic btn_in,    // 원래 버튼 입력 (raw)
    output logic btn_pulse  // 0→1 엣지 시 1클럭 펄스
);
    //============================================================
    // 1) 디바운스 파트: 2단 동기화 + 카운터
    //============================================================
    parameter integer CNT_MAX = 2_000_000; // 20ms @ 100MHz

    reg [21:0] cnt;       // 카운터 (최대 2,000,000까지 셀 수 있음)
    reg        sync_0, sync_1;  // 2단 동기화 플립플롭
    reg        btn_db;         // 디바운스 완료된 버튼 신호

    // 1-1) 2단 동기화 (글리치 제거)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sync_0 <= 1'b0;
            sync_1 <= 1'b0;
        end else begin
            sync_0 <= btn_in;
            sync_1 <= sync_0;
        end
    end

    // 1-2) Debounce 로직: sync_1이 CNT_MAX 동안 유지되면 btn_db 갱신
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cnt    <= 22'd0;
            btn_db <= 1'b0;
        end else begin
            if (sync_1 == btn_db) begin
                cnt <= 22'd0;
            end else begin
                if (cnt == CNT_MAX - 1) begin
                    btn_db <= sync_1;
                    cnt    <= 22'd0;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

    //============================================================
    // 2) 엣지 검출 파트: btn_db의 0→1 전이 때 1클럭 펄스 생성
    //============================================================
    reg prev_db;  // 지난 클럭의 btn_db 값

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            prev_db   <= 1'b0;
            btn_pulse <= 1'b0;
        end else begin
            if (btn_db && !prev_db) begin
                btn_pulse <= 1'b1;
            end else begin
                btn_pulse <= 1'b0;
            end
            prev_db <= btn_db;
        end
    end

endmodule
