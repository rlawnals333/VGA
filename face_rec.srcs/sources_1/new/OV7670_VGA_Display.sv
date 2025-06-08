`timescale 1ns / 1ps

module OV7670_VGA_Display (
    // global signals
    input  logic       clk,
    input  logic       reset,
    // filter signals
    input  logic       sw_red,
    input  logic       sw_green,
    input  logic       sw_blue,
    input  logic       sw_gray,
    input  logic       sw_upscale,
    // ov7670 signals
    output logic       ov7670_xclk,
    input  logic       ov7670_pclk,
    input  logic       ov7670_href,
    input  logic       ov7670_v_sync,
    input  logic [7:0] ov7670_data,
    output logic       ov7670_scl,
    output logic       ov7670_sda,
    // export
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] red_port,
    output logic [3:0] green_port,
    output logic [3:0] blue_port,
    output logic       tx,
    output logic [6:0] led,
    input  logic       capture_trigger, // to use 2 board(hc04)
    input  logic       we_cu            // to use 2 board(hc04)

);

    logic        we;
    logic [14:0] wAddr;
    logic [15:0] wData;
    //logic [16:0] rAddr;
    logic [15:0] rData;
    logic [ 9:0] x_pixel;
    logic [ 9:0] y_pixel;
    logic        DE;
    logic        rclk;
    //logic        oe;
    logic        frame_done;
    //logic        btn_pulse;
    logic        sccb_start;

    // signal for uart
    // (1) QVGA → FrameBuffer 읽기(기존)
    logic        oe_vga;  // QVGA_MemController의 d_en
    logic [14:0] rAddr_vga;  // QVGA_MemController의 rAddr

    // (2) UART 전송용 읽기
    logic        oe_uart;  // frame_uart_sender의 oe_ram
    logic [14:0] rAddr_uart;  // frame_uart_sender의 rAddr_ram

    // (3) 최종 FrameBuffer에 실제 연결될 읽기 포트
    logic        oe;  // frame_buffer의 .oe 포트 (MUX 결과)
    logic [14:0] rAddr;  // frame_buffer의 .rAddr 포트 (MUX 결과)

    // (4) frame_uart_sender ↔ uart_tx 연결 신호
    logic [ 7:0] uart_data;  // frame_uart_sender → uart_tx.data_in
    logic        uart_start;  // frame_uart_sender → uart_tx.send
    logic        uart_ready;  // uart_tx.ready → frame_uart_sender.uart_ready
    logic        uart_busy;
    logic        send_done;  // frame_uart_sender.send_done → uart_mode 제어

    logic        capture_request;
    logic        capture_next_frame;
    // (5) UART 모드 플래그
    logic        uart_mode;  // 0 = VGA 모드, 1 = UART 전송 모드

    //-------------------------------------------------------------------------------------------------------//
    // filter for VGA output (to Monitor)
    logic [ 3:0] red_data;
    logic [ 3:0] green_data;
    logic [ 3:0] blue_data;

    logic [ 9:0] red_to_gray;
    logic [10:0] green_to_gray;
    logic [ 7:0] blue_to_gray;
    logic [11:0] gray_sum;
    logic [ 3:0] gray_data;

    assign red_to_gray = red_data * 77;
    assign green_to_gray = green_data * 150;
    assign blue_to_gray = blue_data * 29;

    assign gray_sum = red_to_gray + green_to_gray + blue_to_gray;

    assign gray_data = gray_sum[11:8];

    assign {red_port, green_port, blue_port} = (sw_gray)  ? {gray_data, gray_data, gray_data} : 
                                               (sw_red)   ? {red_data, 4'b0000, 4'b0000}      :
                                               (sw_green) ? {4'b0000, green_data, 4'b0000}    :
                                               (sw_blue)  ? {4'b0000, 4'b0000, blue_data}     :
                                                            {red_data, green_data, blue_data} ;
    //--------------------------------------------------------------------------------------------------------------//


    // Upscale logic
    logic [9:0] x_pixel_up;
    logic [9:0] y_pixel_up;
    assign x_pixel_up = {1'b0, x_pixel[9:1]};
    assign y_pixel_up = {1'b0, y_pixel[9:1]};

    logic [9:0] x_pixel_mem;
    logic [9:0] y_pixel_mem;
    assign x_pixel_mem = (sw_upscale) ? x_pixel_up : x_pixel;
    assign y_pixel_mem = (sw_upscale) ? y_pixel_up : y_pixel;

    logic prev_frame_done;
    logic new_frame_done;
    assign new_frame_done = frame_done && !prev_frame_done;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) prev_frame_done <= 1'b0;
        else prev_frame_done <= frame_done;
    end

    // mux for vga or uart
    // (A) uart_mode 플래그 제어
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            uart_mode <= 1'b0;
        end else begin
            if (capture_request && new_frame_done) begin
                uart_mode <= 1'b1;
            end if (send_done) begin
                uart_mode <= 1'b0;
            end
        end
    end


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            capture_request <= 1'b0;
        end else begin
            if (capture_trigger) begin // 2 board(hc04)
                capture_request <= 1'b1;
            end if (send_done) begin
                // send_done=1로 전송이 끝나면 capture_request도 클리어
                capture_request <= 1'b0;
            end
        end
    end

    // (B) 읽기 포트 MUX: uart_mode에 따라 선택
    always_comb begin
        if (uart_mode) begin
            oe    = oe_uart;       // UART 전송 모드에서는 frame_uart_sender가 읽기 제어
            rAddr = rAddr_uart;    // UART 전송 모드에서는 frame_uart_sender가 주소 제어
        end else begin
            oe    = oe_vga;        // VGA 모드에서는 QVGA_MemController가 읽기 제어
            rAddr = rAddr_vga;     // VGA 모드에서는 QVGA_MemController가 주소 제어
        end
    end

    


    //-----------------------------------------------------------------------------------------------------------------------//

    pixel_clk_gen UOV7670_Clk_Gen (
        .clk  (clk),
        .reset(reset),
        .pclk (ov7670_xclk)
    );

    VGA_Controller U_VGAController (
        .clk    (clk),
        .reset  (reset),
        .rclk   (rclk),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );

    OV7670_MemController U_OV7670_MemComtroller (
        .pclk       (ov7670_pclk),
        .reset      (reset),
        .href       (ov7670_href),
        .v_sync     (ov7670_v_sync),
        .ov7670_data(ov7670_data),
        .we         (we),
        .wAddr      (wAddr),
        .wData      (wData)
    );

    frame_buffer U_FrameBuffer (
        //write side
        .reset(reset),
        .wclk (ov7670_pclk),
        .we   (we | we_cu), // 2 board(hc04)
        .wAddr(wAddr),
        .wData(wData),
        // read side
        .rclk (rclk),
        .oe   (oe),
        .rAddr(rAddr),
        .rData(rData),
        .frame_done(frame_done)
    );

    QVGA_MemController U_QVGA_MemController (
        .clk       (clk),
        .x_pixel   (x_pixel_mem),
        .y_pixel   (y_pixel_mem),
        .DE        (DE),
        // frame buffer side
        .rclk      (),
        .d_en      (oe_vga),
        .rAddr     (rAddr_vga),
        .rData     (rData),
        // export side
        .red_port  (red_data),
        .green_port(green_data),
        .blue_port (blue_data)
    );


    frame_uart_sender_gray U_Frame_Uart (
        .clk       (clk),
        .reset     (reset),
        .btn_pulse (capture_request && new_frame_done),
        .oe_ram    (oe_uart),
        .rAddr_ram (rAddr_uart),
        .rData_ram (rData),
        .uart_data (uart_data),
        .uart_start(uart_start),
        .uart_busy (uart_busy),
        .uart_ready(uart_ready),
        .send_done (send_done)
    );

    uart_tx U_Uart_Tx (
        .clk(clk),
        .reset(reset),
        .data_in(uart_data),
        .send(uart_start),
        .tx(tx),
        .busy(uart_busy),
        .ready(uart_ready)
    );

    SCCB_intf u_sccb (
        .clk(clk),
        .reset(reset),
        .startSig(sccb_start),
        .SCL(ov7670_scl),
        .SDA(ov7670_sda)
    );

    sccb_start_generator u_start_gen (
        .clk(clk),
        .reset(reset),
        .startSig(sccb_start)
    );

    assign led[0] = uart_busy;
    assign led[1] = uart_ready;
    assign led[2] = send_done;
    assign led[3] = capture_request;
    assign led[4] = frame_done;
    assign led[5] = uart_mode;
    assign led[6] = capture_trigger;

endmodule
