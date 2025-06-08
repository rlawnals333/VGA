`timescale 1ns / 1ps

module uart_tx #(
    parameter integer CLK_FREQ = 100_000_000, // 시스템 클럭 100MHz
    parameter integer BAUD     = 921600       // 보레이트
)(
    input  wire       clk,        // 100MHz
    input  wire       reset,      // Active‐High 리셋
    input  wire [7:0] data_in,    // 전송할 1바이트 데이터
    input  wire       send,       // 1클럭 펄스로 전송 요청
    output reg        tx,         // UART TX 라인 (FPGA 핀)
    output reg        busy,       // 전송 중 표시 (1=전송 중, 0=IDLE)
    output wire       ready       // 다음 바이트 수신 가능 (1=준비 완료)
);

    //============================================================
    // 파라미터 및 로컬파라미터
    //============================================================
    localparam integer DIV = CLK_FREQ / BAUD;       // 분주값 (≈868)
    localparam integer N   = $clog2(DIV);           // 분주 카운터 폭

    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] START   = 2'd1;
    localparam [1:0] DATABIT = 2'd2;
    localparam [1:0] STOP    = 2'd3;

    //============================================================
    // 내부 신호
    //============================================================
    reg [1:0]         state, next_state;
    reg [N-1:0]       baud_cnt;  // 분주 카운터
    reg [3:0]         bit_idx;   // 전송한 데이터 비트 수 (0..7)
    reg [7:0]         sh_reg;    // 시프트 레지스터 (LSB부터 전송)

    //============================================================
    // 1) 상태 전이
    //============================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    //============================================================
    // 2) 메인 동작: 비트 전송 타이밍 제어
    //============================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            baud_cnt <= {N{1'b0}};
            bit_idx  <= 4'd0;
            sh_reg   <= 8'd0;
            tx       <= 1'b1; // Idle 시 TX 라인 High
            busy     <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx   <= 1'b1; // Idle 레벨
                    busy <= 1'b0;
                    // 전송 요청이 들어오면, 새로 데이터 로드 & 비트 인덱스 초기화
                    if (send) begin
                        sh_reg   <= data_in;
                        baud_cnt <= {N{1'b0}};
                        bit_idx  <= 4'd0;
                        busy     <= 1'b1; 
                    end
                end

                START: begin
                    // Start 비트(0)를 1개 비트 타이밍 동안 전송
                    tx <= 1'b0;
                    busy <= 1'b1;
                    if (baud_cnt == DIV - 1) begin
                        baud_cnt <= {N{1'b0}};  
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                DATABIT: begin
                    // 데이터 비트(LSB부터) 8비트 전송
                    tx <= sh_reg[0];
                    busy <= 1'b1;
                    if (baud_cnt == DIV - 1) begin
                        baud_cnt <= {N{1'b0}};
                        sh_reg   <= {1'b0, sh_reg[7:1]}; // 오른쪽으로 1비트 시프트
                        bit_idx  <= bit_idx + 1'b1;
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                STOP: begin
                    // Stop 비트(High) 1개 비트 타이밍 동안 전송
                    tx <= 1'b1;
                    busy <= 1'b1;
                    if (baud_cnt == DIV - 1) begin
                        baud_cnt <= {N{1'b0}};
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                default: begin
                    // (이상 상태 대비)
                    tx   <= 1'b1;
                    busy <= 1'b0;
                    baud_cnt <= {N{1'b0}};
                    bit_idx  <= 4'd0;
                    sh_reg   <= 8'd0;
                end
            endcase
        end
    end

    //============================================================
    // 3) Next-state 로직
    //============================================================
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (send) 
                    next_state = START;
            end

            START: begin
                if (baud_cnt == DIV - 1)
                    next_state = DATABIT;
            end

            DATABIT: begin
                // 8비트를 다 보냈으면 STOP 단계로
                if ((baud_cnt == DIV - 1) && (bit_idx == 4'd7))  
                    next_state = STOP;
            end

            STOP: begin
                if (baud_cnt == DIV - 1)
                    next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    //============================================================
    // 4) ready 신호 생성
    //============================================================
    // IDLE 상태에서만 다음 바이트 수신 가능 => ready=1
    assign ready = (state == IDLE);

endmodule
