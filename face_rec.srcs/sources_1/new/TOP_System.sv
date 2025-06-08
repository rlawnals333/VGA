`timescale 1ns / 1ps


module TOP_System(
    input logic rx_in,
    input logic echo,
    output logic hr_trigger,
    output logic [7:0] led_out,

    output logic [3:0] fndcomm,
    output logic [7:0] fndfont,
    //----------------------//
    input  logic       clk,
    input  logic       reset,
    input  logic       btn,
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
    output logic [6:0] led
    );

    logic capture_trigger, we_cu, btn_pulse;

    OV7670_VGA_Display U_OV7670_VGA(
        .*,
        .capture_trigger(capture_trigger), // to use 2 board(hc04)
        .we_cu(we_cu)            // to use 2 board(hc04)
    );

    top_ctrl U_CU(
        .*,
        .capture_trigger(capture_trigger),
        .w_en(we_cu),
        .btn_pulse(btn_pulse)
    );

    button_debounce_edge U_btn_deb (
        .clk      (clk),
        .reset    (reset),
        .btn_in   (btn),
        .btn_pulse(btn_pulse)
    );

endmodule

