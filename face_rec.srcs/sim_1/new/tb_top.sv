`timescale 1ns / 1ps

//**************************************************************
// tb_full_flow.sv
//
// “프레임 버퍼 → frame_uart_sender → uart_tx” 전체 흐름 검증용 테스트벤치
//
//   • IMG_PIXELS = 320×240 (= 76800 픽셀)  
//   • 프레임 버퍼(behavioral BRAM 모델)를 16’hA1A1로 모두 초기화  
//   • frame_uart_sender 모듈을 통해 16’hA1A1 픽셀을 순차적으로 읽어와  
//     “LSB → MSB” 순서로 uart_tx에 넘겨 직렬 출력여부 확인  
//   • uart_tx는 시뮬레이션 속도 향상을 위해 CLK_FREQ=10, BAUD=1 설정  
//   • send_done 이후 충분히 대기한 뒤 시뮬 종료  
//**************************************************************

module tb_full_flow;
    //──────────────────────────────────────────────────────────────────────────
    // 1) 파라미터 및 로컬파라미터
    //──────────────────────────────────────────────────────────────────────────
    localparam int IMG_WIDTH  = 320;
    localparam int IMG_HEIGHT = 240;
    localparam int IMG_PIXELS = IMG_WIDTH * IMG_HEIGHT; // 76800

    //──────────────────────────────────────────────────────────────────────────
    // 2) Clock & Reset
    //──────────────────────────────────────────────────────────────────────────
    reg clk, reset;
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 10ns 주기 → 100MHz로 간주 (시뮬레이션 속도용)
    end

    initial begin
        reset = 1;
        #20 reset = 0;  // 20ns 시점에서 reset 해제
    end

    //──────────────────────────────────────────────────────────────────────────
    // 3) frame_uart_sender 인터페이스 신호
    //──────────────────────────────────────────────────────────────────────────
    reg                 btn_pulse;       // 캡쳐 요청 1클럭 펄스
    wire                oe_ram;          // BRAM 읽기 enable
    wire [16:0]         rAddr_ram;       // BRAM read address (0..IMG_PIXELS-1)
    reg  [7:0]          rData_ram;       // BRAM → frame_uart_sender 데이터
    wire [7:0]          uart_data;       // frame_uart_sender → uart_tx 바이트
    wire                uart_start;      // frame_uart_sender → uart_tx 전송 요청
    wire                uart_busy;       // uart_tx 전송 중 상태
    wire                uart_ready;      // uart_tx IDLE 상태
    wire                send_done;       // frame_uart_sender → TB 전송 완료
    wire                tx;              // UART TX 직렬 출력

    //──────────────────────────────────────────────────────────────────────────
    // 4) uart_tx 모듈 인스턴스 (시뮬레이션용 빠른 파라미터)
    //──────────────────────────────────────────────────────────────────────────
    uart_tx #(
        .CLK_FREQ(10),  // 시뮬레이션 속도 절감을 위해 낮춤
        .BAUD    (1)
    ) uut_uart (
        .clk    (clk),
        .reset  (reset),
        .data_in(uart_data),
        .send   (uart_start),
        .tx     (tx),
        .busy   (uart_busy),
        .ready  (uart_ready)
    );

    //──────────────────────────────────────────────────────────────────────────
    // 5) frame_uart_sender 모듈 인스턴스 (IMG_PIXELS = 76800)
    //──────────────────────────────────────────────────────────────────────────
    frame_uart_sender_gray #(
        .IMG_PIXELS(IMG_PIXELS)
    ) uut_fus (
        .clk       (clk),
        .reset     (reset),
        .btn_pulse (btn_pulse),
        .oe_ram    (oe_ram),
        .rAddr_ram (rAddr_ram),
        .rData_ram (rData_ram),
        .uart_data (uart_data),
        .uart_start(uart_start),
        .uart_busy (uart_busy),
        .uart_ready(uart_ready),
        .send_done (send_done)
    );

    //──────────────────────────────────────────────────────────────────────────
    // 6) Dummy Frame 버퍼 메모리: 320×240 픽셀 → 모두 16’hA1A1 로 초기화
    //──────────────────────────────────────────────────────────────────────────
    reg [7:0] frame_buffer [0:IMG_PIXELS-1];
    integer    i;
    initial begin
        // 모든 픽셀을 16’hA1A1로 채움
        for (i = 0; i < IMG_PIXELS; i = i + 1) begin
            frame_buffer[i] = 8'hA1;
        end
    end

    //──────────────────────────────────────────────────────────────────────────
    // 7) 동기식 BRAM 모델: 한 클럭 지연된 읽기 (rAddr_dly, oe_dly 사용)
    //──────────────────────────────────────────────────────────────────────────
    reg [16:0] rAddr_dly;  // rAddr_ram 한 클럭 지연
    reg        oe_dly;     // oe_ram 한 클럭 지연

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rAddr_dly <= 17'd0;
            oe_dly    <= 1'b0;
            rData_ram <= 8'd0;
        end else begin
            // ① rAddr_ram → rAddr_dly (한 클럭 지연)
            rAddr_dly <= rAddr_ram;
            // ② oe_ram → oe_dly (한 클럭 지연)
            oe_dly    <= oe_ram;
            // ③ 이전 클럭에 oe_dly=1 이었다면 해당 주소의 frame_buffer 값을 rData_ram에 제공
            if (oe_dly) begin
                rData_ram <= frame_buffer[rAddr_dly];
            end else begin
                rData_ram <= rData_ram; // 아니라면 그대로 유지
            end
        end
    end

    //──────────────────────────────────────────────────────────────────────────
    // 8) Stimulus: btn_pulse 펄스 & 전송 완료 대기
    //──────────────────────────────────────────────────────────────────────────
    initial begin
        // (A) reset 해제 후 충분히 안정화
        btn_pulse = 1'b0;
        #30;  // reset=0 해제 뒤 최소 30ns 대기

        // (B) 버튼 펄스: 한 프레임 전송 요청
        #10 btn_pulse = 1;
           #10 btn_pulse = 0;

        // (C) send_done 펄스를 두 번 기다림 (ST_DONE 상태에서 한 클럭 펄스)
        wait (send_done);
        

        // (D) 마지막 MSB 직렬 비트(10비트 프레임)가 완전히 나갈 시간을 추가 확보
        #200;

        $display(">> 모든 픽셀 전송 완료. 시뮬레이션 종료.");
        $finish;
    end

    //──────────────────────────────────────────────────────────────────────────
    // 9) 파형 저장 (dumpfile / dumpvars)
    //──────────────────────────────────────────────────────────────────────────

endmodule
