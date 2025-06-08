`timescale 1ns / 1ps
/*
module frame_uart_sender #(
    parameter int IMG_PIXELS = 320*240
)(
    input  logic        clk,
    input  logic        reset,       // Active‐High 리셋

    input  logic        btn_pulse,   // 캡쳐 요청 1클럭 펄스

    //───────────────────────────────────────────────────────────────────────────
    // ① 프레임 버퍼(BRAM) 읽기 포트 (동기 BRAM 모델)
    //───────────────────────────────────────────────────────────────────────────
    output logic        oe_ram,      // 1: 읽기 활성화 (Read Enable)
    output logic [16:0] rAddr_ram,   // 읽을 주소 (0..IMG_PIXELS-1)
    input  logic [15:0] rData_ram,   // BRAM에서 읽어온 16비트 픽셀 데이터

    //───────────────────────────────────────────────────────────────────────────
    // ② UART TX 인터페이스
    //───────────────────────────────────────────────────────────────────────────
    output logic [ 7:0] uart_data,   // UART로 보낼 8비트 데이터
    output logic        uart_start,  // 1클럭 펄스: “UART 이 바이트를 전송해 주세요”
    input  logic        uart_busy,   // 1: TX 모듈이 전송 중
    input  logic        uart_ready,  // 1: TX 모듈이 IDLE 상태(다음 바이트 받을 준비)

    //───────────────────────────────────────────────────────────────────────────
    // ③ 전송 완료 알림 (한 프레임 끝나면 1클럭 펄스)
    //───────────────────────────────────────────────────────────────────────────
    output logic        send_done    // 1: 마지막 픽셀 MSB 전송이 끝난 순간
);

    //───────────────────────────────────────────────────────────────────────────
    // 1) FSM 상태 정의 (총 11개 상태: 0..10)
    //───────────────────────────────────────────────────────────────────────────
    typedef enum logic [3:0] {
        ST_IDLE         = 4'd0,
        ST_READ_PIXEL   = 4'd1,
        ST_WAIT_PIXEL   = 4'd2,
        ST_CAPTURE      = 4'd3,
        ST_CAPTURE_OK   = 4'd4,  // **여기서 1클럭 대기**
        ST_SEND_LSB     = 4'd5,
        ST_WAIT_TX_LSB  = 4'd6,
        ST_SEND_MSB     = 4'd7,
        ST_WAIT_TX_MSB  = 4'd8,
        ST_INCR_ADDR    = 4'd9,
        ST_DONE         = 4'd10
    } state_t;

    state_t        state, next_state;
    logic [16:0]   addr_cnt;      // 현재 읽을 픽셀 주소 (0..IMG_PIXELS-1)
    logic [15:0]   pixel_data;    // BRAM에서 읽어온 픽셀값

    //───────────────────────────────────────────────────────────────────────────
    // 2) 순차 블록: 상태 전이 및 내부 레지스터 업데이트
    //───────────────────────────────────────────────────────────────────────────
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // 리셋 시 초기화
            state       <= ST_IDLE;
            addr_cnt    <= 17'd0;
            pixel_data  <= 16'd0;

            oe_ram      <= 1'b0;
            rAddr_ram   <= 17'd0;

            uart_data   <= 8'd0;
            uart_start  <= 1'b0;
            send_done   <= 1'b0;
        end else begin
            // (a) 매 클럭마다 uart_start, send_done은 1클럭만 펄스 주기 위해 먼저 0 설정
            uart_start <= 1'b0;
            send_done  <= 1'b0;

            // (b) 상태 업데이트
            state <= next_state;

            // (c) 상태별 내부 동작
            case (state)
                //────────────────────────────────────── ST_IDLE ──────────────────────────────────────
                ST_IDLE: begin
                    oe_ram <= 1'b0;
                    if (btn_pulse) begin
                        addr_cnt <= 17'd0;
                    end
                end

                //───────────────────────────────── ST_READ_PIXEL ─────────────────────────────────────
                ST_READ_PIXEL: begin
                    // BRAM 읽기 요청 → 다음 상승 에지에 BRAM 모델이 rData_ram <= mem[addr_cnt] 실행 예약
                    oe_ram    <= 1'b1;
                    rAddr_ram <= addr_cnt;
                end

                //───────────────────────────────── ST_WAIT_PIXEL ─────────────────────────────────────
                ST_WAIT_PIXEL: begin
                    // 오직 BRAM 읽어온 것(rData_ram)이 안정될 때를 기다리는 단계
                    oe_ram <= 1'b0;
                end

                //────────────────────────────────── ST_CAPTURE ───────────────────────────────────────
                ST_CAPTURE: begin
                    // BRAM 모델에서 올라온 rData_ram(=mem[addr_cnt])를 pixel_data에 복사
                    //pixel_data <= rData_ram;
                end

                //──────────────────────────────── ST_CAPTURE_OK ──────────────────────────────────────
                ST_CAPTURE_OK: begin
                    // “pixel_data = rData_ram” 구문이 Δ1에서 실행되어 안정되었으니,
                    // 이 상태를 1클럭 동안 머물면서 pixel_data가 확실히 반영되는 시간을 줌.
                    // 별도 동작은 없음. (uart_data, oe_ram 모두 유지 안 함)
                    pixel_data <= rData_ram;
                end

                //────────────────────────────────── ST_SEND_LSB ────────────────────────────────────
                ST_SEND_LSB: begin
                    // “pixel_data[7:0]”를 UART로 보낼 준비
                    uart_data <= pixel_data[7:0];
                    if ((uart_ready == 1'b1) && (uart_busy == 1'b0)) begin
                        uart_start <= 1'b1;
                    end
                end

                //──────────────────────────────── ST_WAIT_TX_LSB ──────────────────────────────────
                ST_WAIT_TX_LSB: begin
                    // “uart_busy=1” 될 때까지 기다림 → 그 순간 ST_SEND_MSB로 전이
                end

                //────────────────────────────────── ST_SEND_MSB ────────────────────────────────────
                ST_SEND_MSB: begin
                    // “pixel_data[15:8]”를 UART로 보낼 준비
                    uart_data <= pixel_data[15:8];
                    if ((uart_ready == 1'b1) && (uart_busy == 1'b0)) begin
                        uart_start <= 1'b1;
                    end
                end

                //──────────────────────────────── ST_WAIT_TX_MSB ──────────────────────────────────
                ST_WAIT_TX_MSB: begin
                    // “uart_busy=1” 될 때까지 대기 → 그 순간 ST_INCR_ADDR로 전이
                end

                //───────────────────────────────── ST_INCR_ADDR ────────────────────────────────────
                ST_INCR_ADDR: begin
                    // 한 픽셀(LSB+MSB) 전송이 끝난 시점에서
                    if (addr_cnt < IMG_PIXELS - 1) begin
                        addr_cnt <= addr_cnt + 1;
                    end
                end

                //──────────────────────────────────── ST_DONE ───────────────────────────────────────
                ST_DONE: begin
                    // 마지막 픽셀 MSB 전송 개시 순간 → send_done=1 1클럭 펄스
                    send_done <= 1'b1;
                end

                //──────────────────────────────────────── DEFAULT ─────────────────────────────────────
                default: begin
                    oe_ram     <= 1'b0;
                    uart_start <= 1'b0;
                    send_done  <= 1'b0;
                end
            endcase
        end
    end

    //───────────────────────────────────────────────────────────────────────────
    // 3) 조합 블록: next_state 계산 (FSM 전이조건)
    //───────────────────────────────────────────────────────────────────────────
    always_comb begin
        next_state = state;
        case (state)
            // ST_IDLE → ST_READ_PIXEL (btn_pulse=1 감지 시)
            ST_IDLE: begin
                if (btn_pulse) next_state = ST_READ_PIXEL;
            end

            // ST_READ_PIXEL → ST_WAIT_PIXEL (항상 Δ1 뒤)
            ST_READ_PIXEL: next_state = ST_WAIT_PIXEL;

            // ST_WAIT_PIXEL → ST_CAPTURE (항상 Δ2 뒤: rData_ram이 유효해진 뒤)
            ST_WAIT_PIXEL: next_state = ST_CAPTURE;

            // ST_CAPTURE → ST_CAPTURE_OK (항상 Δ3 뒤)
            ST_CAPTURE: next_state = ST_CAPTURE_OK;

            // **ST_CAPTURE_OK → ST_SEND_LSB (항상 Δ1 뒤: pixel_data가 완전히 반영된 뒤)**
            ST_CAPTURE_OK: next_state = ST_SEND_LSB;

            // ST_SEND_LSB → ST_WAIT_TX_LSB  
            //   (uart_start=1이 된 시점의 다음 클럭에 ST_WAIT_TX_LSB로 전이)
            ST_SEND_LSB: begin
                if (uart_start == 1'b1) next_state = ST_WAIT_TX_LSB;
                else                    next_state = ST_SEND_LSB;
            end

            // ST_WAIT_TX_LSB → ST_SEND_MSB 
            //   (uart_busy=1이 된 순간: LSB 전송 개시됐을 때)
            ST_WAIT_TX_LSB: begin
                if (uart_busy == 1'b1) next_state = ST_SEND_MSB;
                else                   next_state = ST_WAIT_TX_LSB;
            end

            // ST_SEND_MSB → ST_WAIT_TX_MSB 
            //   (uart_start=1이 된 시점의 다음 클럭에 ST_WAIT_TX_MSB로 전이)
            ST_SEND_MSB: begin
                if (uart_start == 1'b1) next_state = ST_WAIT_TX_MSB;
                else                    next_state = ST_SEND_MSB;
            end

            // ST_WAIT_TX_MSB → ST_INCR_ADDR 
            //   (uart_busy=1이 된 순간: MSB 전송 개시됐을 때)
            ST_WAIT_TX_MSB: begin
                if (uart_busy == 1'b1) next_state = ST_INCR_ADDR;
                else                   next_state = ST_WAIT_TX_MSB;
            end

            // ST_INCR_ADDR → ST_READ_PIXEL (addr_cnt < IMG_PIXELS-1) 또는 ST_DONE
            ST_INCR_ADDR: begin
                if (addr_cnt < IMG_PIXELS - 1) next_state = ST_READ_PIXEL;
                else                           next_state = ST_DONE;
            end

            // ST_DONE → ST_IDLE (항상 Δ1 뒤)
            ST_DONE: next_state = ST_IDLE;

            default: next_state = ST_IDLE;
        endcase
    end

endmodule
*/
// 0604 code: RGB data transmit to PC -> complete
//-------------------------------------------------------------------------------------------//
// RGB data -> Gray Scale convert, transmit to PC

`timescale 1ns / 1ps

module frame_uart_sender_gray #(
    parameter int IMG_PIXELS = 160 * 120
) (
    input logic clk,
    input logic reset,     // Active‐High 리셋
    input logic btn_pulse, // 캡쳐 요청 1클럭 펄스

    // BRAM 읽기 포트 (동기 BRAM)
    output logic        oe_ram,
    output logic [14:0] rAddr_ram,
    input  logic [15:0] rData_ram,  // 16비트 RGB565

    // UART TX 인터페이스
    output logic [7:0] uart_data,   // Gray 1바이트
    output logic       uart_start,
    input  logic       uart_busy,
    input  logic       uart_ready,

    // 전송 완료 알림 (한 프레임 끝나면 1클럭 펄스)
    output logic send_done
);

    //──────────────────────────────────────────────────────────────────
    // 1) FSM 상태 정의 (총 9개 상태)
    //──────────────────────────────────────────────────────────────────
    typedef enum logic [3:0] {
        ST_IDLE = 4'd0,
        ST_READ_PIXEL = 4'd1,  // BRAM 읽기 시작 → 다음 클럭에 rData_ram valid
        ST_WAIT_PIXEL = 4'd2,  // rData_ram이 안정될 때까지 1클럭 쉼
        ST_CAPTURE = 4'd3,  // rData_ram → pixel_data(레지스터)에 샘플
        ST_CAPTURE_OK = 4'd4,
        ST_CONVERT = 4'd5,  // pixel_data → gray_data 계산
        ST_CONVERT_WAIT = 4'd6,
        ST_SEND_GRAY = 4'd7,  // UART로 gray_data 보내기
        ST_WAIT_TX = 4'd8,  // UART busy가 걸릴 때까지 대기
        ST_INCR_ADDR = 4'd9,  // 다음 픽셀 주소 증가
        ST_DONE = 4'd10  // 끝났으면 1클럭 send_done 펄스
    } state_t;

    state_t state, next_state;
    logic [16:0] addr_cnt;  // 읽을 픽셀 주소 (0..IMG_PIXELS-1)
    logic [15:0] pixel_data;  // BRAM에서 읽어온 16비트 RGB565
    logic [ 7:0] gray_data;  // 계산된 8비트 그레이 값


    //──────────────────────────────────────────────────────────────────
    // 2) 순차 블록: state 전이 및 내부 레지스터 업데이트 (모두 non‐blocking)
    //──────────────────────────────────────────────────────────────────
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // 초기화
            state      <= ST_IDLE;
            addr_cnt   <= 17'd0;
            pixel_data <= 16'd0;
            gray_data  <= 8'd0;

            oe_ram     <= 1'b0;
            rAddr_ram  <= 17'd0;

            uart_data  <= 8'd0;
            uart_start <= 1'b0;
            send_done  <= 1'b0;
        end else begin
            // (a) 매 클럭마다 일회성 펄스(reset 제외)는 0으로 먼저 내려 둠
            uart_start <= 1'b0;
            send_done  <= 1'b0;

            // (b) 상태 전이
            state      <= next_state;

            // (c) 상태별 내부 동작
            case (state)
                //────────────────────────────── ST_IDLE ───────────────────────────────
                ST_IDLE: begin
                    oe_ram <= 1'b0;
                    if (btn_pulse) begin
                        addr_cnt <= 17'd0;
                    end
                end

                //─────────────────────────── ST_READ_PIXEL ────────────────────────────
                ST_READ_PIXEL: begin
                    // BRAM 읽기 활성화
                    oe_ram    <= 1'b1;
                    rAddr_ram <= addr_cnt;
                end

                //─────────────────────────── ST_WAIT_PIXEL ────────────────────────────
                ST_WAIT_PIXEL: begin
                    // 한 클럭 동안 대기 → rData_ram이 안정되도록 함
                    oe_ram <= 1'b0;
                end

                //──────────────────────────── ST_CAPTURE ───────────────────────────────
                ST_CAPTURE: begin
                    // BRAM에서 올라온 rData_ram(=mem[addr_cnt])를 pixel_data에 복사
                    //pixel_data <= rData_ram;
                end

                ST_CAPTURE_OK: begin
                    // “pixel_data = rData_ram” 구문이 Δ1에서 실행되어 안정되었으니,
                    // 이 상태를 1클럭 동안 머물면서 pixel_data가 확실히 반영되는 시간을 줌.
                    // 별도 동작은 없음. (uart_data, oe_ram 모두 유지 안 함)
                    pixel_data <= rData_ram;
                end

                //──────────────────────────── ST_CONVERT ───────────────────────────────
                ST_CONVERT: begin
                    // pixel_data에 저장된 RGB565를 바로 그레이로 변환
                    // (비동기 산술 연산 전체를 한 줄에서 계산)
                    gray_data <= (
                                    (
                                      (((pixel_data[15:11]) * 255 / 31) * 76) +
                                      (((pixel_data[10: 5]) * 255 / 63) * 150) +
                                      (((pixel_data[ 4: 0]) * 255 / 31) * 29)
                                    ) >> 8
                                 );
                    if ((uart_ready == 1'b1) && (uart_busy == 1'b0)) begin
                        uart_start <= 1'b1;
                    end
                end

                ST_CONVERT_WAIT: begin
                    // gray_data가 register에 안정될 시간을 벌기 위해 딱 1클럭 쉬고
                    // 아무것도 하지 않습니다.
                end

                //──────────────────────────── ST_SEND_GRAY ────────────────────────────
                ST_SEND_GRAY: begin
                    // gray_data(8비트)를 UART로 보낼 준비
                    uart_data <= gray_data;
                    if (uart_ready && !uart_busy) begin
                        uart_start <= 1'b1;
                    end
                end

                //───────────────────────────── ST_WAIT_TX ──────────────────────────────
                ST_WAIT_TX: begin
                    // uart_busy = 1 되는 순간 ST_INCR_ADDR로 전이 (아래 next_state 참조)
                end

                //─────────────────────────── ST_INCR_ADDR ─────────────────────────────
                ST_INCR_ADDR: begin
                    // 한 픽셀(1바이트 그레이) 전송을 끝냈다면 주소 증가
                    if (addr_cnt < IMG_PIXELS - 1) begin
                        addr_cnt <= addr_cnt + 1;
                    end
                end

                //───────────────────────────── ST_DONE ─────────────────────────────────
                ST_DONE: begin
                    // 마지막 픽셀 전송이 끝나는 순간 1클럭 send_done 펄스
                    send_done <= 1'b1;
                end

                //────────────────────────────DEFAULT─────────────────────────────────────
                default: begin
                    oe_ram     <= 1'b0;
                    uart_start <= 1'b0;
                    send_done  <= 1'b0;
                end
            endcase
        end
    end


    //──────────────────────────────────────────────────────────────────
    // 3) 조합 블록: next_state 계산
    //──────────────────────────────────────────────────────────────────
    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE: if (btn_pulse) next_state = ST_READ_PIXEL;

            ST_READ_PIXEL: next_state = ST_WAIT_PIXEL;
            ST_WAIT_PIXEL: next_state = ST_CAPTURE;

            ST_CAPTURE:      next_state = ST_CAPTURE_OK;
            ST_CAPTURE_OK:   next_state = ST_CONVERT;
            ST_CONVERT:      next_state = ST_CONVERT_WAIT;
            ST_CONVERT_WAIT: next_state = ST_SEND_GRAY;

            ST_SEND_GRAY:
            if (uart_start) next_state = ST_WAIT_TX;
            else next_state = ST_SEND_GRAY;

            ST_WAIT_TX:
            if (uart_busy) next_state = ST_INCR_ADDR;
            else next_state = ST_WAIT_TX;

            ST_INCR_ADDR:
            if (addr_cnt < IMG_PIXELS - 1) next_state = ST_READ_PIXEL;
            else next_state = ST_DONE;

            ST_DONE: next_state = ST_IDLE;

            default: next_state = ST_IDLE;
        endcase
    end

endmodule
