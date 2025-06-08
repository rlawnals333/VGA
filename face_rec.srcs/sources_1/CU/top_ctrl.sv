`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/05 11:12:14
// Design Name: 
// Module Name: top_ctrl
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


module top_ctrl(
    input logic clk,
    input logic reset,
    input logic rx_in,
    input logic echo,
    output logic hr_trigger,
    output logic capture_trigger,
    output logic [15:0] led_out,
    input  logic btn_pulse,

    output logic [3:0] fndcomm,
    output logic [7:0] fndfont,
    output logic w_en
    );

logic rx_done, hr_done, us_start_trigger;
logic [7:0] rx_data;
logic [8:0] distance_data;
logic [3:0] fnd_data;
ControlUnit U_CU(
    .clk(clk),
    .reset(reset),
    .uart_rx_done(rx_done),
    .uart_in(rx_data),
    .distance_in(distance_data),
    .measure_done(hr_done),
    .btn_pulse(btn_pulse),

    .capture_trigger(capture_trigger),
    .hr04_trigger(us_start_trigger),
    .fnd_data(fnd_data),
    .led_out(led_out),
    .w_en(w_en)
    
    );

 uart_rx u_UART_RX(
    .clk(clk),
    .reset(reset),
    .rx_in(rx_in),


    .rx_out(rx_data),
    .rx_busy(),
    .rx_done(rx_done)
);

us_control  u_hr04 (

    .clk(clk),
    .reset(reset),
    .SR04_data(echo),
    .start(us_start_trigger),
    // input logic [2:0] sw_mode,

    .start_trigger(hr_trigger),
    .distance(distance_data),
    .measure_done(hr_done)
    // output logic is_measure
   
    );


fnd_ip u_FND(

    .clk(clk),
    .reset(reset),
    // input logic [3:0] FMR,
    
    .FDR(fnd_data),
    // input logic [3:0] FPR,

    .fndcomm(fndcomm),
    .fndfont(fndfont)
    );



endmodule
