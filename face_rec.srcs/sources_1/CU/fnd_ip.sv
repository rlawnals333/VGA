`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/22 11:26:08
// Design Name: 
// Module Name: fnd_ip
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


module fnd_ip #(parameter FCOUNT = 1000_00)(

    input logic clk,
    input logic reset,
    // input logic [3:0] FMR,
    
    input logic [4:0] FDR,
    // input logic [3:0] FPR,

    output logic [3:0] fndcomm,
    output logic [7:0] fndfont
    );


    logic [1:0] sel;
    logic [3:0] FMR;

counter #(.FCOUNT(FCOUNT)) u_counter_1khz(
    .clk(clk),
    .reset(reset),

    .sel(sel)

);

    assign FMR = (sel == 0) ? 4'b0001 : (sel == 1)? 4'b0010 : (sel == 2) ? 4'b0100 : 4'b1000;

    genvar i;
    generate
        for(i=0;i<4;i++) begin
            assign fndcomm[i] = ~FMR[i];
        end
    endgenerate

   
    // 걍 assign fndcomm = ~FMR ; 하면돼
    logic [3:0] num_1,num_10,num_100,num_1000;
    assign num_1 = FDR %10;
    assign num_10 = FDR /10%10;
    assign num_100 = FDR /100%10;
    assign num_1000 = FDR /1000%10;


    logic [3:0] font;
    logic [7:0] t_fndfont;
    logic is_dot;
    // assign font = (FMR == 4'b0001) ? num_1 : (FMR == 4'b0010) ? num_10 :
    //               (FMR == 4'b0100) ? num_100 :(FMR == 4'b1000) ? num_1000 : 0;
    always_comb begin
        font = 0;
        if(FDR == 6) begin //fail
           font =  (FMR == 4'b0001) ? 13 : (FMR == 4'b0010) ? 1:(FMR == 4'b0100) ? 12 :(FMR == 4'b1000) ? 11 : 0;  
        end
        else if(FDR == 7)  begin //pass
            font =  (FMR == 4'b0001) ? 5 : (FMR == 4'b0010) ? 5 :(FMR == 4'b0100) ? 12 :(FMR == 4'b1000) ? 10  : 0;  
        end
        else if(FDR ==5) begin //scan
            font =  (FMR == 4'b0001) ? 6 : (FMR == 4'b0010) ? 12 :(FMR == 4'b0100) ? 7 :(FMR == 4'b1000) ? 5  : 0;  
        end
        else if(FDR ==8) begin //save
            font =  (FMR == 4'b0001) ? 4 : (FMR == 4'b0010) ? 8 :(FMR == 4'b0100) ? 12 :(FMR == 4'b1000) ? 5  : 0;  
        end
        else if((FDR == 1) || (FDR == 2) || (FDR == 3)) begin
            font =  (FMR == 4'b0001) ? num_1 : (FMR == 4'b0010) ? 14 :(FMR == 4'b0100) ? 14 :(FMR == 4'b1000) ? 14  : 0;  
        end
        else begin // ...
            font =  (FMR == 4'b0001) ? 9 : (FMR == 4'b0010) ? 9 :(FMR == 4'b0100) ? 9 :(FMR == 4'b1000) ? 9 : 0; 
        end
    end

    always_comb begin
        fndfont = 8'hff;
       
        case(font)
        0: fndfont = 8'hc0; //0
        1: fndfont = 8'hCF; //1
        2: fndfont = 8'ha4; //2
        3: fndfont = 8'hb0; //3
        4: fndfont = 8'h86; // E
        5: fndfont = 8'h92; // s
        6: fndfont = 8'hC8; // n
        7: fndfont = 8'hC6; //c
        8: fndfont = 8'hC1; // U
        9: fndfont = 8'h7F; //dot
        10:fndfont = 8'h8C; //p
        11:fndfont = 8'h8E;  //F
        12:fndfont = 8'h88; //a
        13:fndfont = 8'hC7; //l
        14:fndfont = 8'hFF; // 다꺼짐 

        endcase
        
    end

//    assign is_dot = (FMR&FPR)? 0 : 1'b1;

//         assign  fndfont = {is_dot,t_fndfont[6:0]};

 //dp memory 하나 추가 c언어로 dot 포인트 지정 
endmodule



module counter #(parameter FCOUNT = 1000_00, BIT_SIZE = $clog2(FCOUNT)) (
    input logic clk,
    input logic reset,

    output logic [1:0] sel

);
    logic [BIT_SIZE-1:0] counter;
    
  always_ff @(posedge clk, posedge reset) begin
    if(reset) begin 
        sel <= 0;
        counter <= 0;
    end
    else begin
        if(counter == FCOUNT -1) begin
            sel <= sel + 1;
            counter <= 0;
        end
        else counter <= counter + 1;
    end
  end

  
endmodule